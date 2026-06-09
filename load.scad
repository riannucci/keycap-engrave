// A folder name in `caps/`
keycapFamily = "klp_lame";

// The basename of a JSON in `caps/<keycapFamily>/`
keycapVariant = "choc_choc";

// The name of an entry in the JSON file.
keycapName = "n";

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
  echo(str(entry, ": ", caps[entry].stl));
}

cap = caps[keycapName];

module model() {
  rotate([0, 0, keycapRotate])
    import(str("caps/", keycapFamily, "/upstream/", cap["stl"]), center=true);
}

module legend(legend, font, size, platform, shift, tilt) {
  tm = textmetrics(text=legend, size=size, halign="center", valign="center", font=font);
  echo(tm);

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
      legend(legPri, legPriFont, legPriSize, cap.floor, legPriVecXY, cap.tilt);
      legend(legSec, legSecFont, legSecSize, cap.floor, legSecVecXY, cap.tilt);
      legend(legTrt, legTrtFont, legTrtSize, cap.floor, legTrtVecXY, cap.tilt);
    }

  color(legPriColor)
    intersection() {
      model();
      legend(legPri, legPriFont, legPriSize, cap.floor, legPriVecXY, cap.tilt);
    }

  color(legSecColor)
    intersection() {
      model();
      legend(legSec, legSecFont, legSecSize, cap.floor, legSecVecXY, cap.tilt);
    }

  color(legTrtColor)
    intersection() {
      model();
      legend(legTrt, legTrtFont, legTrtSize, cap.floor, legTrtVecXY, cap.tilt);
    }
}
