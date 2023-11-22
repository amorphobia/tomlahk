add_rules("mode.debug", "mode.release")

target("libtoml")
    set_kind("shared")
    add_files("toml.c")

    if is_plat("windows") then
        add_rules("utils.symbols.export_all")
    end
