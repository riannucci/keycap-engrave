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
import re
import tomllib
import typing


@dataclasses.dataclass
class Legend:
    index: int

    text: str = ""
    color: str = ""
    font: str = ""
    size: float = 0
    shiftXY: None | tuple[float, float] = None
    skip: bool = False
    translucent: bool = False

    def to_dict(self, colormap: typing.Callable[[str], str]):
        if not self.text:
            return {}
        return {
            f"Legend{self.index}Text": self.text,
            f"Legend{self.index}Color": colormap(self.color),
            f"Legend{self.index}Font": self.font,
            f"Legend{self.index}Size": self.size,
            f"Legend{self.index}VecXY": self.shiftXY,
            f"Legend{self.index}Skip": self.skip,
            f"Legend{self.index}Translucent": self.translucent,
        }

    @staticmethod
    def from_data(variant: int, data: dict) -> Legend:
        return Legend(variant).with_data(data)

    def with_data(self, data: dict) -> Legend:
        # If any values are the default sentinel, reset the value to its default.
        for key, value in data.items():
            if value == []:
                data[key] = getattr(Legend, key)
        return dataclasses.replace(self, **data)


@dataclasses.dataclass
class Keycap:
    family: str = dataclasses.field(default="", metadata={"p": "families"})
    variant: str = dataclasses.field(default="", metadata={"p": "variants"})
    kind: str = dataclasses.field(default="", metadata={"p": "kinds"})
    color: str = dataclasses.field(default="", metadata={"p": "colors"})

    legend: dict[int, Legend] = dataclasses.field(
        default_factory=dict,
        metadata={"p": "legends"},
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
        for legend in self.legend.values():
            ret.update(legend.to_dict(colormap))
        # Filter all empty stuff out.
        ret = {k: v for k, v in ret.items() if v}
        # Explicitly add back empty legends - otherwise the file default will bleed through.
        for legend in range(1, 6):
            ret.setdefault(f"Legend{legend}Text", "")
        return ret

    @staticmethod
    def from_data(data: dict) -> Keycap:
        return Keycap().with_data(data)

    def with_data(self, data: dict) -> Keycap:
        data = copy.deepcopy(data)
        # If any values are the default sentinel, reset the value to its default.
        for key, value in data.items():
            if value == []:
                data[key] = getattr(Legend, key)
        legend = data.pop("legend", {})
        ret = dataclasses.replace(self, **data)
        for legend_idx, leg in legend.items():
            legend_idx = int(legend_idx)
            if legend_idx not in self.legend:
                self.legend[legend_idx] = Legend(legend_idx)
            self.legend[legend_idx] = self.legend[legend_idx].with_data(leg)
        return ret

    @property
    def should_output(self):
        return any(l.text for l in self.legend.values())

    @property
    def batch_key(self) -> tuple[typing.Any, ...]:
        key: list[typing.Any] = [self.family, self.variant, self.kind, self.color]
        for leg in self.legend.values():
            if leg.text:
                key.append(leg.color)
        if self.rotate:
            key.append(self.rotate)
        return tuple(key)


PluralDict = dict[str, list[typing.Any] | dict[str, typing.Any]]
SparseDict = dict[int, dict[str, typing.Any]]


def depluralize(data: PluralDict) -> SparseDict:
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
        legend_plurals: dict[int, SparseDict] = collections.defaultdict(dict)
        plurals: PluralDict = collections.defaultdict(list)
        singulars = {}
        for field in dataclasses.fields(Keycap):
            if (plural := field.metadata["p"]) in data:
                if plural == "legends":
                    for idx, legend in data.pop(plural).items():
                        legend_plurals[int(idx)] = depluralize(legend)
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

        for legend_idx, sdict in legend_plurals.items():
            for key_idx, data in sdict.items():
                key = keys[key_idx]
                key.legend[legend_idx] = key.legend[legend_idx].with_data(data)

        if base.should_output:
            keys["base"] = base

        return Row(name, keys)


@dataclasses.dataclass
class BatchConfig:
    size: int = 10
    ignorelist: list[str] = dataclasses.field(default_factory=list)

    @property
    def finished_pat(self) -> re.Pattern:
        return re.compile("^(" + ")|(".join(self.ignorelist) + ")$")


@dataclasses.dataclass
class Global:
    rows: dict[str, Row]

    default: Keycap = dataclasses.field(default_factory=Keycap)

    batch: BatchConfig = dataclasses.field(default_factory=BatchConfig)

    colors: dict[str, str] = dataclasses.field(default_factory=dict)

    @staticmethod
    def from_data(data: dict, ignorelist: list[str]) -> Global:
        batchRaw = data.pop("batch", {})
        batchRaw["ignorelist"] = ignorelist
        batch = BatchConfig(**batchRaw)
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
        finish_pat = self.batch.finished_pat
        for rowName, row in self.rows.items():
            for i, cap in row.keys.items():
                name = f"{rowName}_{i}"
                if finish_pat.match(name):
                    continue
                ret[name] = cap
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
    parser.add_argument(
        "--ignorelist",
        "-i",
        help="Path to a TOML which is a list of regexes of key names to skip.",
    )
    parser.add_argument("input_toml", help="Path to the input TOML file")
    args: argparse.Namespace = parser.parse_args()

    with open(args.input_toml, "rb") as f:
        ignorelist = []
        if args.ignorelist:
            with open(args.ignorelist, "rb") as igf:
                ignorelist = json.load(igf)
        parsed = Global.from_data(tomllib.load(f), ignorelist)

    presets = {}
    for i, batch in enumerate(parsed.batched()):
        for name, cap in batch.items():
            presets[f"batch{i}/{name}"] = cap.to_dict(parsed.colormap)

    with open("engrave.json", "w") as f:
        json.dump({"parameterSets": presets, "fileFormatVersion": "1"}, f)

    common_args = ["--enable", "lazy-union", "--enable", "import-function"]

    if args.preview:

        async def do_preview():
            await (
                await asyncio.subprocess.create_subprocess_exec(
                    "openscad",
                    *common_args,
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
                    outfile = f"output/{name}.3mf"
                    os.makedirs(os.path.dirname(outfile), exist_ok=True)
                    await (
                        await asyncio.subprocess.create_subprocess_exec(
                            "openscad",
                            "-p",
                            "engrave.json",
                            "-P",
                            name,
                            "-o",
                            outfile,
                            *common_args,
                            "engrave.scad",
                        )
                    ).wait()

            async with asyncio.TaskGroup() as grp:
                for name in presets:
                    grp.create_task(render(name))

        asyncio.run(render_all())


if __name__ == "__main__":
    main()
