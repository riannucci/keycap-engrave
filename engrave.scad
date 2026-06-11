// A folder name in `caps/`
keycapFamily = "klp_lame";

// The basename of a JSON in `caps/<keycapFamily>/`
keycapVariant = "choc_choc";

// The name of an entry in the JSON file.
keycapKind = "n";

// Rotate legend.
legendRotate = 0;

// Color of the keycap.
keycapColor = "#1a1a1a";

// Primary Legend.
legPri = "";
// Primary Legend color.
legPriColor = "white";
// Primary Legend font.
legPriFont = "FiraCode Nerd Font:style=Medium";
// Primary Legend size.
legPriSize = 4;
// Primary Legend offset (X, Y) from center.
legPriVecXY = [0, 3];

// Secondary Legend.
legSec = "";
// Secondary Legend color.
legSecColor = "blue";
// Secondary Legend font.
legSecFont = "FiraCode Nerd Font:style=Medium";
// Secondary Legend size.
legSecSize = 3;
// Secondary Legend offset (X, Y) from center.
legSecVecXY = [-3, -3];

// Tertiary Legend.
legTrt = "";
// Tertiary Legend color.
legTrtColor = "green";
// Tertiary Legend font.
legTrtFont = "FiraCode Nerd Font:style=Medium";
// Tertiary Legend size.
legTrtSize = 3;
// Tertiary Legend offset (X, Y) from center.
legTrtVecXY = [3, -3];

// If true, will render the keycap body with transparency.
// Useful for setting the "floor" when adding new keycap JSONs.
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
        if (truncated) model();

        safezone();

        // Extrude it back along the Z axis.
        embiggen()
          // project it onto XY.
          projection(cut=false)
            // flop it back into position.
            flopped()
              // Put the pancake back exactly where it was.
              translate([0, 0, -0.001])
                difference() {
                  // calculate a little "pancake" of the letter projected onto the 
                  // flipped keycap.
                  translate([0, 0, 0.001])
                    intersection() {
                      flipped() model();
                      shifted() embiggen() legText();
                      safezone();
                    }

                  intersection() {
                    flipped() model();
                    shifted() embiggen() legText();
                    safezone();
                  }

                  // remove the model again to delete cruft from the
                  // translated text extrusion.
                  flipped() model();
                }
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
