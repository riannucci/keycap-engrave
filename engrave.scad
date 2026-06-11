/* [Keycap] */

// A folder name in `caps/`
keycapFamily = "klp_lame";

// The basename of a JSON in `caps/<keycapFamily>/`
keycapVariant = "choc_choc";

// The name of an entry in the JSON file.
keycapKind = "n";

// Rotate legend.
legendRotate = 0; // [0:359]

// Color of the keycap.
keycapColor = "#1a1a1a";

/* [Primary Legend] */

// Text
legPri = "";
// Color
legPriColor = "white";
// Font.
legPriFont = "FiraCode Nerd Font:style=Medium";
// Size.
legPriSize = 4;
// Offset (X, Y) from center.
legPriVecXY = [0, 3];

/* [Secondary Legend] */

// Text
legSec = "";
// Color
legSecColor = "blue";
// Font
legSecFont = "FiraCode Nerd Font:style=Medium";
// Size
legSecSize = 3;
// Offset (X, Y) from center.
legSecVecXY = [-3, -3];

/* [Tertiary Legend] */

// Text
legTrt = "";
// Color
legTrtColor = "green";
// Font
legTrtFont = "FiraCode Nerd Font:style=Medium";
// Size
legTrtSize = 3;
// Offset (X, Y) from center.
legTrtVecXY = [3, -3];

/* [Debug] */

// Makes keycap body translucent in preview. Useful for finding the "floor" when adding new keycap JSONs.
debugClearBody = false;

caps = import(str("caps/", keycapFamily, "/", keycapVariant, ".json"));

// The $default section of the cap variant JSON.
default = caps["$default"];

// The specific keycap section in the cap variant JSON.
cap = caps[keycapKind];

if (is_undef(cap)) {
  echo("Found caps:");
  for (entry = caps) {
    if (entry != "$default") {
      echo(entry);
    }
  }
  assert(!is_undef(cap), str("Unknown keycap: caps/", keycapFamily, "/", keycapVariant, ".json: ", keycapKind));
}

$fa = 0.01;
$fs = 0.01;

// get retrieves from a keycap json:
//   * The value directly in the keycap entry (keycapKind).
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
    import(str("caps/", keycapFamily, "/upstream/", path), center=true);
}

// Safezone is a giant cube lifted to the floor of the keycap.
module safezone() {
  translate([0, 0, 50 + get("floor", 0)])
    cube([100, 100, 100], center=true);
}

// Flipped orients its children by tilting them by the keycap's tilt, then
// rotating them around Z by the inverse of `legendRotate`.
//
// When visualizing this, it will rotate the keycap so it's face is directly
// up along Z, and then rotating it so that letters stamped into it will 
// appear with `legendRotate`.
//
// The effects of flipped are exactly reversed by `flopped`.
module flipped() {
  rotate([0, 0, legendRotate])
    rotate([-get("tilt", 0), 0, 0])
      children();
}

// Flopped is the exact inverse of flipped.
module flopped() {
  rotate([get("tilt", 0), 0, 0])
    rotate([0, 0, -legendRotate])
      children();
}

legends = [
  [legPri, legPriColor, legPriFont, legPriSize, legPriVecXY],
  [legSec, legSecColor, legSecFont, legSecSize, legSecVecXY],
  [legTrt, legTrtColor, legTrtFont, legTrtSize, legTrtVecXY],
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

  if (text_val != "") {
    color(colorr) intersection() {
        // Extrude it back along the Z axis. Now we have a correctly
        // tilt-corrected letter, extruded exactly along Z.
        embiggen()
          // Project it onto XY.
          projection(cut=false)
            // Flop the pancake into it's ultimate position.
            flopped()
              intersection() {
                // Move it down a smidge to embed it in the cap.
                translate([0, 0, -0.001])
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

        // Make sure this doesn't intersect the stem/bottom of the cap.
        safezone();

        // If we're truncating, make sure the resulting legend doesn't
        // poke above the model.
        if (truncated) model();
      }
  }
}

// NOTE: It's important that this NOT be turned into a module, or even grouped
// with a single render(). Otherwise even with `lazy-union`, OpenSCAD will
// implicitly union the output of the module, and there will only be one
// exported body.

// 1. Base keycap with legends carved out.

module renderBody() {
  if (debugClearBody) {
    %render() children();
  } else {
    render() children();
  }
}

renderBody() color(keycapColor) difference() {
      model();

      legend(legends[0]);
      legend(legends[1]);
      legend(legends[2]);
    }

// Each legend generated and colored separately.
render() legend(legends[0], truncated=true);
render() legend(legends[1], truncated=true);
render() legend(legends[2], truncated=true);
