# TODO

- Ensure this works with MX style keycaps.
- Give it the ability to engrave on surfaces other than the face (e.g. front
  printed). Probably good to combo with engrave.
- Add json for other keycaps
- Add support for STEP inputs.
- Add support for SCAD inputs (will probably need to switch to `use` for the
  model, as well as a config of how to call the relevant module).
- Add support for negative engraving to allow font to bump out from key surface
  (and make sure this supports Braille unicode dot patterns). This will probably
  also require making the negative engrave have a rounded exterior.
- Add support for per-key slant as well as tilt.
- Add support for non-vertical extrusion for FDM. Sometimes it's nice to be able
  to print keycaps on an incline (e.g. 70 degrees) rather than verticallys (e.g.
  to reduce visible scarring on the surface of the cap visible when it's
  installed). This comes with some other negative tradeoffs though (e.g. choc
  stems will now have stairsteps on their thin edges). Still, it would be a
  useful feature to have to prevent extra filament changes for
  invisible/interior portions of the legends. Or maybe upstream a feature to
  OrcaSlicer to allow filtering away invisible filament changes? Seems like it
  could be generally useful...
- Add proper README.md.
