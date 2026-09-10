-- NKS compact window appearance/animation skin.
hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 4,
        border_size = 1,
        layout = "master",
    },
    decoration = {
        rounding = 0,
        active_opacity = 1.0,
        inactive_opacity = 0.75,
        blur = {
            enabled = true,
            size = 5,
            passes = 2,
            vibrancy = 0.1696,
        },
    },
    master = {
        new_on_top = false,
        mfact = 0.5,
        orientation = "left",
    },
})

hl.config({
    animations = {
        enabled = true,
        bezier = {
            "snappy, 0.15, 1.0, 0.1, 1.0",
            "snappyOut, 0.3, 0.0, 0.8, 0.15",
            "liner, 1, 1, 1, 1",
            "almostLinear, 0.5, 0.5, 0.75, 1.0",
        },
        animation = {
            "windows, 1, 3, snappy, slide",
            "windowsIn, 1, 3, snappy, slide",
            "windowsOut, 1, 2, snappyOut, slide",
            "windowsMove, 1, 3, snappy, slide",
            "border, 1, 1, liner",
            "borderangle, 1, 30, liner, loop",
            "layers, 1, 2, snappy, popin 90%",
            "layersIn, 1, 2, snappy, popin 90%",
            "layersOut, 1, 1.5, snappyOut, popin 90%",
            "workspaces, 1, 2.5, snappy",
            "fadeIn, 1, 1.0, almostLinear",
            "fadeOut, 1, 1.0, almostLinear",
            "fade, 1, 1.0, almostLinear",
        },
    },
})
