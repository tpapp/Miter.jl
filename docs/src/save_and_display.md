# Saving and displaying graphics

Graphics can be saved with `Miter.save`.

```@docs
Miter.save
```

Whenever multimedia output is supported, Miter attempts to show plots graphically, via `Base.show`. Currently `.png` and `.svg` files are supported. They can be customized via `Miter.Options`.

```@docs
Miter.Options.set_default_resolution
Miter.Options.get_default_resolution
Miter.Options.set_show_format
Miter.Options.get_show_format
```
