# rotating hypercube projections using conformal geometric algebra on a webgl canvas

status: currently being migrated from canvas to webgl. the rotation axes controls are hidden because they are not migrated.

there is currently no point of reset, so the model might degenerate after a while because of floating point errors.

[demo](https://sph.mn/files/u/software/sourcecode/cga-hypercubes/src/main.html)

# info
* the compiled javascript file is compiled/main.js
* the source file is main.coffee (using [coffeescript](http://coffeescript.org/), "npm install coffeescript")
* deployment: make the project directory accessible via http using a web server then open main.html in a browser and an animation should appear
* license: public domain

uses
* [sph-ga](https://github.com/sph-mn/sph-ga) (lgpl license)
* [crel](https://github.com/KoryNunn/crel) (mit license)
