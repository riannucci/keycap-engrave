// A folder name in `caps/`
keycapFamily = "klp_lame";

// The basename of a JSON in `caps/<keycapFamily>/`
keycapVariant = "choc_choc";

// The name of an entry in the JSON file.
keycapKind = "n";

// Rotate keycap before applying legend. No effect for caps without tilt.
keycapRotate = 0;

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

caps = import(str("caps/", keycapFamily, "/", keycapVariant, ".json"));
echo("Found caps:");
for (entry = caps) {
  if (entry != "$default") {
    echo(str(entry, ": ", caps[entry].stl));
  }
}

default = caps["$default"];
cap = caps[keycapKind];

function get(key, fallback) =
  (
    !is_undef(cap[key]) ? cap[key]
    : (
      !is_undef(default[key]) ? default[key] : fallback
    )
  );

module model() {
  path = is_undef(default.rootPath) ? cap.stl : str(default.rootPath, cap.stl);

  rotate([0, 0, keycapRotate])
    import(str("caps/", keycapFamily, "/upstream/", path), center=true);
}

module legend(legend, font, size, shift) {
  tm = textmetrics(text=legend, size=size, halign="center", valign="center", font=font);

  tilt = get("tilt", 0);
  platform = get(key="floor", fallback=0);

  translate(concat(shift, platform))
    translate([-(tm.size.x / 2), 0, 0])
      rotate([keycapRotate ? -tilt : tilt, 0, 0])
        translate([tm.size.x / 2, 0, 0])
          linear_extrude(height=15)
            text(text=legend, size=size, halign="center", valign="center", font=font);
}

render() {
  color(keycapColor) difference() {
      model();
      legend(legPri, legPriFont, legPriSize, legPriVecXY);
      legend(legSec, legSecFont, legSecSize, legSecVecXY);
      legend(legTrt, legTrtFont, legTrtSize, legTrtVecXY);
    }

  color(legPriColor)
    intersection() {
      model();
      legend(legPri, legPriFont, legPriSize, legPriVecXY);
    }

  color(legSecColor)
    intersection() {
      model();
      legend(legSec, legSecFont, legSecSize, legSecVecXY);
    }

  color(legTrtColor)
    intersection() {
      model();
      legend(legTrt, legTrtFont, legTrtSize, legTrtVecXY);
    }
}
