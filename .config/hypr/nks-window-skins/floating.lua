-- NKS legacy window appearance/animation skin.
hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 24,
        border_size = 2,
        layout = "dwindle",
    },
    decoration = {
        rounding = 16,
        rounding_power = 2,
        active_opacity = 0.92,
        inactive_opacity = 0.45,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(000000ff)",
        },
        blur = {
            enabled = true,
            size = 5,
            passes = 2,
            vibrancy = 0.1696,
        },
    },
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
})

hl.config({
    animations = {
        enabled = true,
        bezier = {
            "wind, 0.05, 0.9, 0.1, 1.05",
            "winIn, 0.1, 1.1, 0.1, 1.1",
            "winOut, 0.3, -0.3, 0, 1",
            "liner, 1, 1, 1, 1",
            "almostLinear, 0.5, 0.5, 0.75, 1.0",
        },
        animation = {
            "windows, 1, 6, wind, slide",
            "windowsIn, 1, 6, winIn, slide",
            "windowsOut, 1, 5, winOut, slide",
            "windowsMove, 1, 6, wind, slide",
            "border, 1, 1, liner",
            "borderangle, 1, 30, liner, loop",
            "layers, 1, 6, wind, popin 90%",
            "layersIn, 1, 6, winIn, popin 90%",
            "layersOut, 1, 5, winOut, popin 90%",
            "workspaces, 1, 5, wind",
            "fadeIn, 1, 1.73, almostLinear",
            "fadeOut, 1, 1.46, almostLinear",
            "fade, 1, 3.03, almostLinear",
        },
    },
})
