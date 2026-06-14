# Custom Keycap Engraver

This repo is built around a simple(?) OpenSCAD program, `engrave.scad` which
allows loading a keyboard keycap STL, and then inscribing legends into it.

The ultimate intent is to be able to generate a full keyboard worth of keycaps,
so that they can be 3D printed (either at home or by sending them off to a
service with an SLS machine). If you're interested in this, then *probably*
you'd be fine with totally unlabeled keys, too, but I like the aesthetic of
labeled keys, already know how to touch type, and it also helps when explaining
for my QWERTY-oriented friends).

I wrote this as a spinoff of https://github.com/coredump/keycap-legends, which
was a great intro to the topic, but a tad too slow (generating a single key took
something like 10s on my machine, `engrave.scad` takes about 0.2s), buggy
(certain legend settings caused the script to crash) and rigid (extending it to
e.g. correct for projection on tilted keycaps was pretty tricky) for my tastes
(something something vibecode something :smile:). I'm sure I could have poked
and prodded an agent to get something better, but I enjoyed doing this one the
old fashioned way (and now I have a basic understanding of OpenSCAD, which is
neat!).

## Quickstart

### Prerequisites

Get the [OpenSCAD] *development snapshot*. I used `2026.06.07 (git 52c25cfd5)`
successfully, but it's likely that newer versions will work fine.

In particular, this repo requires the following 'experimental' features of
OpenSCAD to work properly:

- `lazy-union` - Without this, OpenSCAD will only emit an STL with the keycap
  body and legend inserts unioned together, making it impossible to assign
  different materials to them in e.g. a slicer.
- `import-function` - Without this, `engrave.scad` will not be able to load the
  keycap JSON files specified by the `KeyFamily` and `KeyVariant` parameters.

### Playing around with the customizer

Once you have OpenSCAD, you can just do `openscad engrave.py` and it should open
with the customizer panel prepopulated with some useful basic configuration.

> [!NOTE]
>
> If this is the first time you're opening OpenSCAD, you will need to do a bit
> of extra setup.

<details>
<summary>Extra one-time UI setup.</summary>

To make the OpenSCAD UI display keycaps properly, you must first enable
`lazy-union` and `import-function` features. This is not necessary for directly
using `engrave.py` because it enables these explicitly on the command line.

![Enablement of  and  features in the UI](./docs/photos/EnableFeatures.png)

Additionally, if you want to use a custom font and want the Customizer view of
the font to be accurate, you should also adjust this in the UI as well. This is
not necessary for getting an accurate preview in the atual model viewport, just
on the customizer pane.

![Adjustment of Customizer Font](./docs/photos/SetCustomizerFont.png)

</details>

From here you should see something that looks like this (there may be a lot of
extra little panels for e.g. font selection, colors, animation, etc.. You can
safely close them all by clicking the small `x` in their top left corners):

![Screenshot of engrave.scad](./docs/photos/BaseScreenshot.png)

From here you can play with the settings in the customizer UI on the side, and
you should see OpenSCAD preview the changes fairly quickly (less than a second).

When you've got a feel for the settings you like, you can move on to generating
all the keys for your keyboard at the same time.

### Generating engraved caps

## Notes on 3D printing keycaps

### FDM

### SLS/SLA

## Repo Layout

### engrave.py

#### Caplist TOML

### engrave.scad

`engrave.scad` is the core of the magic in this repo.

#### Keycap Definitions

Keycaps are defined in the `caps/` directory, with each directory describing a
separate 'family' of keycaps, with one or more 'variants'. Each variant is
represented by a uniquely named JSON file, which tells `engrave.scad` where to
find the STL for one or more particular keycap models within this family+variant
combination.

Each keycap family has an `upstream` subdirectory (a Git submodule) which has
the actual model files.

See [#Options] for current key families with links to their OG sources which
have renderings of the base keycaps.

##### Keycap JSON

The keycap JSON has a pretty basic format. It's an object, with each key of the
object representing one, named, keycap. In addition, the key `$default` is used
to make some common base settings for each individual keycap.

Each of these keycap definitions is an object with the following keys:

- `rootPath` - Relative path within `upstream/` of the root of the model files.
- `stl` - Relative path from `upstream/{rootPath}/` of where to find the STL for
  this keycap.
- `tilt` - Degrees to tilt the keycap to orient so that it's face normal is
  exactly along Z.
- `floor` - Offset plane from Z of the non-rotated keycap for what is considered
  safe to engrave. `engrave.scad` will not extrude geometry below this plane.

See [./caps/klp_lame/choc_choc.json] for an example.

#### Options

`{XXX}` below means `Primary`, `Secondary`, or `Tertiary`, refering to the three
possible legends which can be carved into the keycap.

- `KeyFamily` - A folder name under `caps/` in this repo. Currently:
  - [klp_lame](https://github.com/braindefender/KLP-Lame-Keycaps)
  - [clp_keycaps](https://github.com/vvhg1/clp-keycaps)
  - [subliminal_contradiction](https://github.com/pseudoku/Subliminal-Contradiction)
- `KeyVariant` - The name of one of the Keycap JSON files.
- `KeyKind` - The name of one of the keys in the Keycap JSON files.
- `KeyColor` - A valid OpenSCAD color.
- `RotateLegendSet` - Rotate all the legends around the keycap's normal vector
  by this many degrees.
- `KeyTranslucent` - In preview mode, this is useful for seeing the interior
  extrusion of the legends into the keycap model.
- `KeySkip` - Skip emitting the model entirely (e.g. just output the legend
  models).
- `EngraveDepth` - For SLA/SLS printing (or monochrome FDM printing) where you
  intend to fill in the legend manually in some way (or just leave it as a
  shallow indentation). If this is zero, then the model will extrude legend
  models into the keycap model along the true Z axis (not the keycap face normal
  vector) down to the keycap floor. With this > 0, it will instead do an engrave
  extruded along the face normal with an even depth along the face of the
  keycap. The intent is for SLA/SLS prints where you will fill the legends in as
  a post-processing step somehow.
- `KeepEngraved` - If `EngraveDepth` is > 0, keep the engraved legend models
  anyway.
- `{XXX}Legend` - The text to use for this legend. If blank, this legend will be
  skipped.
- `{XXX}Color` - The color to use for this legend.
- `{XXX}Font` - The OpenSCAD font string to use for this legend.
- `{XXX}Size` - The text size to use for this legend (~= the height of the
  rendered text).
- `{XXX}VecXY` - An [X, Y] vector on the plane perpendicular to the keycap's
  face in which to slide this legend's text from center. `[0, 0]` would be dead
  center.
- `{}Skip` - Boolean indicating that this legend should be skipped when
  rendering the output key. This legend will still be engraved into the model
  (assuming the `{XXX}Legend` is not empty), but the geometry for the actual
  legend will be omitted.
- `{}Translucent` - Boolean indicating that this legend will be rendered as
  translucent in the OpenSCAD preview.

[openscad]: https://openscad.org/
