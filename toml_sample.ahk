#Requires AutoHotkey v2.0
#Include "toml.ahk"

fatal(msg, msg1) {
    Throw(Error("ERROR: " . msg . msg1))
}

main() {
    ; 1. Read and parse toml file
    file_object := FileOpen("sample.toml", "r")
    conf := toml_parse_file(file_object, &err)
    file_object.Close()

    if not conf
        fatal("cannot parse - ", err)

    ; 2. Traverse to a table.
    server := toml_table_in(conf, "server")
    if not server
        fatal("missing [server]", "")

    ; 3. Extract values
    host := toml_string_in(server, "host")
    if not host.ok
        fatal("cannot read server.host", "")

    portarray := toml_array_in(server, "port")
    if not portarray
        fatal("cannot read server.port", "")

    msg := "host: " . host.s . "`r`nport: "
    Loop {
        port := toml_int_at(portarray, A_Index - 1)
        if not port.ok
            break
        msg := msg . String(port.i) . " "
    }
    MsgBox(msg)

    ; 4. Free memory
    free(host.u)
    toml_free(conf)
}

main()
