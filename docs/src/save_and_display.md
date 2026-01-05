# Saving and displaying graphics

Graphics can be saved with `Miter.save`.

```@docs
Miter.save
```

Whenever multimedia output is supported, Miter attempts to show plots graphically, by overloading `Base.show`. Currently `.png` and `.svg` files are supported. They can be customized via `Miter.Options`.

```@docs
Miter.options.set_default_resolution
Miter.options.get_default_resolution
Miter.options.set_show_format
Miter.options.get_show_format
```
