#!/usr/bin/env python3

import argparse
import asyncio
import collections
import copy
import dataclasses
import itertools
import json
import multiprocessing
import os
import tomllib
import typing

Variant = typing.Literal["Primary", "Secondary", "Tertiary"]


def parse_variant(v: str | Variant) -> Variant:
    match v.capitalize():
        case "Primary":
            return "Primary"
        case "Secondary":
            return "Secondary"
        case "Tertiary":
            return "Tertiary"
    raise ValueError(f"Unknown variant {v!r}")


@dataclasses.dataclass
class Legend:
    variant: Variant

    legend: str = ""
    color: str = ""
    font: str = ""
    size: float = 0
    shiftXY: None | tuple[float, float] = None
    skip: bool = False
    translucent: bool = False

    def to_dict(self, colormap: typing.Callable[[str], str]):
        return {
            f"{self.variant}Legend": self.legend,
            f"{self.variant}Color": colormap(self.color),
            f"{self.variant}Font": self.font,
            f"{self.variant}Size": self.size,
            f"{self.variant}VecXY": self.shiftXY,
            f"{self.variant}Skip": self.skip,
            f"{self.variant}Translucent": self.translucent,
        }

    @staticmethod
    def from_data(variant: str | Variant, data: dict) -> Legend:
        return Legend(parse_variant(variant)).with_data(data)

    def with_data(self, data: dict) -> Legend:
        return dataclasses.replace(self, **data)


@dataclasses.dataclass
class Keycap:
    family: str = dataclasses.field(default="", metadata={"p": "families"})
    variant: str = dataclasses.field(default="", metadata={"p": "variants"})
    kind: str = dataclasses.field(default="", metadata={"p": "kinds"})
    color: str = dataclasses.field(default="", metadata={"p": "colors"})

    primary: Legend = dataclasses.field(
        default_factory=lambda: Legend("Primary"),
        metadata={"p": "primaries", "l": True},
    )
    secondary: Legend = dataclasses.field(
        default_factory=lambda: Legend("Secondary"),
        metadata={"p": "secondaries", "l": True},
    )
    tertiary: Legend = dataclasses.field(
        default_factory=lambda: Legend("Tertiary"),
        metadata={"p": "tertiaries", "l": True},
    )

    rotate: float = dataclasses.field(default=0, metadata={"p": "rotations"})
    translucent: bool = dataclasses.field(default=False, metadata={"p": "translucents"})
    skip: bool = dataclasses.field(default=False, metadata={"p": "skips"})
    engraveDepth: float = dataclasses.field(default=0, metadata={"p": "engraveDepths"})
    keepEngraved: bool = dataclasses.field(
        default=False, metadata={"p": "keepEngraveds"}
    )

    def to_dict(
        self, colormap: typing.Callable[[str], str]
    ) -> typing.Mapping[str, typing.Any]:
        ret = {
            "KeyFamily": self.family,
            "KeyVariant": self.variant,
            "KeyKind": self.kind,
            "KeyColor": colormap(self.color),
            "RotateLegendSet": self.rotate,
            "KeyTranslucent": self.translucent,
            "KeySkip": self.skip,
            "EngraveDepth": self.engraveDepth,
            "KeepEngraved": self.keepEngraved,
        }
        if self.primary.legend:
            ret.update(self.primary.to_dict(colormap))
        if self.secondary.legend:
            ret.update(self.secondary.to_dict(colormap))
        if self.tertiary.legend:
            ret.update(self.tertiary.to_dict(colormap))
        # Filter all empty stuff out.
        ret = {k: v for k, v in ret.items() if v}
        # Explicitly add back empty legends - otherwise the file default will bleed through.
        for legend in ("Primary", "Secondary", "Tertiary"):
            ret.setdefault(f"{legend}Legend", "")
        return ret

    @staticmethod
    def from_data(data: dict) -> Keycap:
        return Keycap().with_data(data)

    def with_data(self, data: dict) -> Keycap:
        data = copy.deepcopy(data)
        for leg in ("primary", "secondary", "tertiary"):
            if dat := data.pop(leg, None):
                data[leg] = getattr(self, leg).with_data(dat)
        return dataclasses.replace(self, **data)

    @property
    def should_output(self):
        return self.primary.legend or self.secondary.legend or self.tertiary.legend

    @property
    def batch_key(self) -> tuple[typing.Any, ...]:
        key: list[typing.Any] = [self.family, self.variant, self.kind, self.color]
        for leg in (self.primary, self.secondary, self.tertiary):
            if leg.legend:
                key.append(leg.color or self.color)
        if self.rotate:
            key.append(self.rotate)
        return tuple(key)


PluralDict = dict[str, list[typing.Any] | dict[str, typing.Any]]


def depluralize(data: PluralDict) -> dict[int, dict[str, typing.Any]]:
    """Consumes either:

    {
        'key':       [some, values],
        'other_key': [other, more],
    }

    OR

    {
        'key':       {'0': some, '1': values},
        'other_key': {'0': other, '1': more},
    }

    Or any combination within the same dict like:

    {
        'key':       {'0': some, '1': values},
        'other_key': [other, more],
    }

    And yields:

    {
        0: {'key': some, 'other_key': other},
        1: {'key': values, 'other_key': more},
    }
    """
    if not data:
        return {}
    ret = collections.defaultdict(dict)
    for key, item in data.items():
        if isinstance(item, list):
            for i, value in enumerate(item):
                if value:
                    ret[i][key] = value
        else:
            assert isinstance(item, dict)
            for idx, value in item.items():
                if value:
                    ret[int(idx)][key] = value
    return ret


@dataclasses.dataclass
class Row:
    name: str

    keys: dict[str | int, Keycap]

    @staticmethod
    def from_data(name: str, default: Keycap, data: dict) -> Row:
        # This data is both a Keycap and also has plurals of all Keycap fields.
        # The plurals are dicts whose keys are Keycap fields, and whose values are
        # lists. All plural values MUST have the same length, or this will raise
        # an error. We will keep all keys which have a legend.
        legend_plurals: dict[str, PluralDict] = collections.defaultdict(dict)
        plurals: PluralDict = collections.defaultdict(list)
        singulars = {}
        for field in dataclasses.fields(Keycap):
            if (plural := field.metadata["p"]) in data:
                if "l" in field.metadata:
                    legend_plurals[field.name] = data.pop(plural)
                else:
                    plurals[field.name] = data.pop(plural)

            if field.name in data:
                singulars[field.name] = data.pop(field.name)
        if data:
            ValueError(f"Unrecognized data: {data!r}")

        base = default.with_data(singulars)

        keys: dict[str | int, Keycap] = collections.defaultdict(
            lambda: copy.deepcopy(base)
        )
        for idx, data in depluralize(plurals).items():
            keys[idx] = keys[idx].with_data(data)
        for legend, pdict in legend_plurals.items():
            for idx, data in depluralize(pdict).items():
                key = keys[idx]
                setattr(key, legend, getattr(key, legend).with_data(data))

        if base.should_output:
            keys["base"] = base

        return Row(name, keys)


@dataclasses.dataclass
class BatchConfig:
    size: int = 10


@dataclasses.dataclass
class Global:
    rows: dict[str, Row]

    default: Keycap = dataclasses.field(default_factory=Keycap)

    batch: BatchConfig = dataclasses.field(default_factory=BatchConfig)

    colors: dict[str, str] = dataclasses.field(default_factory=dict)

    @staticmethod
    def from_data(data: dict) -> Global:
        batch = BatchConfig(**data.pop("batch", {}))
        colors = data.pop("colors", {})
        default = Keycap.from_data(data.pop("default", {}))
        rows = {}
        for rowName, row in data.pop("rows").items():
            rows[rowName] = Row.from_data(rowName, default, row)
        if data:
            ValueError(f"Unrecognized data: {data!r}")
        return Global(rows, default, batch, colors)

    def colormap(self, color: str) -> str:
        if color.startswith("$"):
            return self.colors[color[1:]]
        return color

    def batched(self) -> list[dict[str, Keycap]]:
        ret = {}
        for rowName, row in self.rows.items():
            for i, cap in row.keys.items():
                ret[f"{rowName}_{i}"] = cap
        if not self.batch.size:
            return [ret]
        by_color: dict[tuple[typing.Any, ...], list[tuple[str, Keycap]]] = (
            collections.defaultdict(list)
        )
        for name, cap in ret.items():
            by_color[cap.batch_key].append((name, cap))
        batches = []
        for name_caps in by_color.values():
            batches.extend(
                dict(batch) for batch in itertools.batched(name_caps, self.batch.size)
            )
        return batches


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert Keycap TOML to OpenSCAD Parameter Set JSON"
    )
    parser.add_argument(
        "--preview",
        "-p",
        action="store_true",
        help="If set, run `openscad` to preview changes.",
    )
    parser.add_argument(
        "--render",
        "-r",
        action="store_true",
        help="If set, render all caps to output/",
    )
    parser.add_argument("input_toml", help="Path to the input TOML file")
    args: argparse.Namespace = parser.parse_args()

    with open(args.input_toml, "rb") as f:
        parsed = Global.from_data(tomllib.load(f))

    presets = {}
    for i, batch in enumerate(parsed.batched()):
        for name, cap in batch.items():
            presets[f"batch{i}/{name}"] = cap.to_dict(parsed.colormap)

    with open("engrave.json", "w") as f:
        json.dump({"parameterSets": presets, "fileFormatVersion": "1"}, f)

    if args.preview:

        async def do_preview():
            await (
                await asyncio.subprocess.create_subprocess_exec(
                    "openscad",
                    "--enable",
                    "all",
                    "engrave.scad",
                )
            ).wait()

        asyncio.run(do_preview())
        if args.render:
            if input("looks good? (y/N): ").lower() != "y":
                return

    if args.render:

        async def render_all():
            sem = asyncio.Semaphore(multiprocessing.cpu_count())

            async def render(name: str):
                async with sem:
                    os.makedirs(os.path.dirname(name), exist_ok=True)
                    await (
                        await asyncio.subprocess.create_subprocess_exec(
                            "openscad",
                            "-p",
                            "engrave.json",
                            "-P",
                            name,
                            "-o",
                            f"output/{name}.3mf",
                            "--enable",
                            "all",
                            "engrave.scad",
                        )
                    ).wait()

            async with asyncio.TaskGroup() as grp:
                for name in presets:
                    grp.create_task(render(name))

        asyncio.run(render_all())


if __name__ == "__main__":
    main()
