/* [Keycap] */

// A folder name in `caps/`
KeyFamily = "klp_lame";

// The basename of a JSON in `caps/<KeyFamily>/`
KeyVariant = "choc_choc";

// The name of an entry in the JSON file.
KeyKind = "n";

// Color of the keycap.
KeyColor = "#1a1a1a";

/* [Global Options] */

// Rotate all legends.
RotateLegendSet = 0; // [0:359]

// Makes keycap body translucent in preview. Useful for finding the "floor" when adding new keycap JSONs.
KeyTranslucent = false;

// Skips rendering the keycap entirely.
KeySkip = false;

// (SLA/SLS) Legends will be made as engravings of this depth, instead of FDM-friendly extrusions.
EngraveDepth = 0; // [0:0.01:1]

// Colored legends will be kept when in engrave mode.
KeepEngraved = false;

/* [Legend1] */

// Text
Legend1Text = "P";
// Color
Legend1Color = "white";
// Font.
Legend1Font = "FiraCode Nerd Font:style=Medium";
// Size.
Legend1Size = 4; // [1:0.01:6]
// Offset (X, Y) from center.
Legend1VecXY = [0, 3]; // [-4:.1:4]
// Skip rendering the legend.
Legend1Skip = false;
// Rendering the legend as translucent.
Legend1Translucent = false;

/* [Legend2] */

// Text
Legend2Text = "S";
// Color
Legend2Color = "blue";
// Font
Legend2Font = "FiraCode Nerd Font:style=Medium";
// Size
Legend2Size = 3; // [1:0.01:6]
// Offset (X, Y) from center.
Legend2VecXY = [-3, -3]; // [-4:.1:4]
// Skip rendering the legend.
Legend2Skip = false;
// Rendering the legend as translucent.
Legend2Translucent = false;

/* [Legend3] */

// Text
Legend3Text = "T";
// Color
Legend3Color = "green";
// Font
Legend3Font = "FiraCode Nerd Font:style=Medium";
// Size
Legend3Size = 3; // [1:0.01:6]
// Offset (X, Y) from center.
Legend3VecXY = [3, -3]; // [-4:.1:4]
// Skip rendering the legend.
Legend3Skip = false;
// Rendering the legend as translucent.
Legend3Translucent = false;

/* [Legend4] */

// Text
Legend4Text = "4";
// Color
Legend4Color = "red";
// Font
Legend4Font = "FiraCode Nerd Font:style=Medium";
// Size
Legend4Size = 3; // [1:0.01:6]
// Offset (X, Y) from center.
Legend4VecXY = [3, 3]; // [-4:.1:4]
// Skip rendering the legend.
Legend4Skip = false;
// Rendering the legend as translucent.
Legend4Translucent = false;

/* [Legend5] */

// Text
Legend5Text = "5";
// Color
Legend5Color = "purple";
// Font
Legend5Font = "FiraCode Nerd Font:style=Medium";
// Size
Legend5Size = 3; // [1:0.01:6]
// Offset (X, Y) from center.
Legend5VecXY = [-3, 3]; // [-4:.1:4]
// Skip rendering the legend.
Legend5Skip = false;
// Rendering the legend as translucent.
Legend5Translucent = false;

caps = import(str("caps/", KeyFamily, "/", KeyVariant, ".json"));

// The $default section of the cap variant JSON.
default = caps["$default"];

// The specific keycap section in the cap variant JSON.
cap = caps[KeyKind];

if (is_undef(cap)) {
  echo("Found caps:");
  for (entry = caps) {
    if (entry != "$default") {
      echo(entry);
    }
  }
  assert(!is_undef(cap), str("Unknown keycap: caps/", KeyFamily, "/", KeyVariant, ".json: ", KeyKind));
}

$fa = 0.01;
$fs = 0.01;

// get retrieves from a keycap json:
//   * The value directly in the keycap entry (KeyKind).
//   * The value in the keycap JSON $default
function get(key, fallback) =
  (
    !is_undef(cap[key]) ? cap[key]
    : (
      !is_undef(default[key]) ? default[key] : fallback
    )
  );

// Yields the keycap model, normalized for insrciption.
//
// Loaded model is centered and any per-STL rotation done to get it with:
//   * Cap face pointing up along Z.
//   * Cap's top (if it was installed in a keyboard) pointing along positive Y.
module model() {
  path = is_undef(default.rootPath) ? cap.stl : str(default.rootPath, cap.stl);
  rotate([0, 0, get("rotate", 0)])
    import(str("caps/", KeyFamily, "/upstream/", path), center=true);
}

// Safezone is a giant cube lifted to the floor of the keycap.
module safezone() {
  translate([0, 0, 50 + get("floor", 0)])
    cube([100, 100, 100], center=true);
}

// Flipped orients its children by tilting them by the keycap's tilt, then
// rotating them around Z by the inverse of `RotateLegendSet`.
//
// When visualizing this, it will rotate the keycap so it's face is directly
// up along Z, and then rotating it so that letters stamped into it will 
// appear with `RotateLegendSet`.
//
// The effects of flipped are exactly reversed by `flopped`.
module flipped() {
  rotate([0, 0, RotateLegendSet])
    rotate([-get("tilt", 0), 0, 0])
      children();
}

// Flopped is the exact inverse of flipped.
module flopped() {
  rotate([get("tilt", 0), 0, 0])
    rotate([0, 0, -RotateLegendSet])
      children();
}

legends = [
  [Legend1Text, Legend1Color, Legend1Font, Legend1Size, Legend1VecXY],
  [Legend2Text, Legend2Color, Legend2Font, Legend2Size, Legend2VecXY],
  [Legend3Text, Legend3Color, Legend3Font, Legend3Size, Legend3VecXY],
  [Legend4Text, Legend4Color, Legend4Font, Legend4Size, Legend4VecXY],
  [Legend5Text, Legend5Color, Legend5Font, Legend5Size, Legend5VecXY],
];

module legend(leg, truncated = false) {
  text_val = leg[0];
  colorr = leg[1];
  font = leg[2];
  size = leg[3];
  shift = leg[4];

  module shifted() {
    translate([shift[0], shift[1], 0]) children();
  }
  module unshifted() {
    translate([-shift[0], -shift[1], 0]) children();
  }
  module embiggen() {
    translate([0, 0, -10])
      linear_extrude(height=20)
        children();
  }

  module legText() {
    text(text=text_val, size=size, halign="center", valign="center", font=font);
  }

  // Generates a letter with given thickness, with the same curvature as the cap 
  // surface, *just* below the cap surface.
  //
  // Pancake must be flopped to get it back into it's ultimate location.
  module pancake(thickness) {
    // TODO: It's also possible to do this by projecting the model, extruding it
    // up to the floor, then using the union of that plus the model to produce a
    // cutting tool whose top surface is the same as the keycap surface. The 
    // benefit of this would be that for very deep engravings, they can currently
    // have their bottom interact with the bottom of the model, and this weird
    // geometry persists after translating the pancake up into the engraving 
    // position.
    intersection() {
      // Move it down by thickness to embed it in the cap.
      translate([0, 0, thickness])
        // calculate a letter tower starting at the model face and
        // going up. 
        difference() {
          intersection() {
            shifted() embiggen() legText();
            safezone();
          }
          flipped() model();
        }

      // Now only keep the smidgen, resulting in a wafer thin 
      // pancake letter exactly on the surface of the cap.
      flipped() model();
    }
  }

  if (text_val != "") {
    color(colorr) if (EngraveDepth == 0) {
      intersection() {
        // Extrude it back along the Z axis. Now we have a correctly
        // tilt-corrected letter, extruded exactly along Z.
        embiggen()
          // Project it onto XY.
          projection(cut=false)
            // Flop the pancake into it's ultimate position.
            flopped()
              pancake(-0.001);

        // Make sure this doesn't intersect the stem/bottom of the cap.
        safezone();

        // If we're truncating, make sure the resulting legend doesn't
        // poke above the model.
        if (truncated) model();
      }
    } else {
      intersection() {
        // Flop it into it's ultimate position.
        flopped()
          // Now poke it up above the cap surface for clean intersections.
          translate([0, 0, 1])
            // Make a pancake which is too deep.
            pancake(-(EngraveDepth + 1));

        // If we're truncating, make sure the resulting legend doesn't
        // poke above the model.
        if (truncated) model();
      }
    }
  }
}

module maybeRender(translucent = false) {
  if (translucent) {
    %render() children();
  } else {
    render() children();
  }
}

// NOTE: It's important that this NOT be turned into a module, or even grouped
// with a single render(). Otherwise even with `lazy-union`, OpenSCAD will
// implicitly union the output of the module, and there will only be one
// exported body.

// Base keycap with legends carved out.
if (!KeySkip) {
  maybeRender(translucent=KeyTranslucent) color(KeyColor) difference() {
        model();

        legend(legends[0]);
        legend(legends[1]);
        legend(legends[2]);
        legend(legends[3]);
        legend(legends[4]);
      }
}

// Each legend generated and colored separately.
if (!Legend1Skip && (EngraveDepth == 0 || KeepEngraved)) {
  maybeRender(Legend1Translucent) legend(legends[0], truncated=true);
}
if (!Legend2Skip && (EngraveDepth == 0 || KeepEngraved)) {
  maybeRender(Legend2Translucent) legend(legends[1], truncated=true);
}
if (!Legend3Skip && (EngraveDepth == 0 || KeepEngraved)) {
  maybeRender(Legend3Translucent) legend(legends[2], truncated=true);
}
if (!Legend4Skip && (EngraveDepth == 0 || KeepEngraved)) {
  maybeRender(Legend4Translucent) legend(legends[3], truncated=true);
}
if (!Legend5Skip && (EngraveDepth == 0 || KeepEngraved)) {
  maybeRender(Legend5Translucent) legend(legends[4], truncated=true);
}
