/*
 * AutoHotkey port of toml_cat.c
 * Copyright (c) 2023 Xuesong Peng <pengxuesong.cn@gmail.com>
 * 
 * Original C program MIT License
 * Copyright (c) CK Tan
 * https://github.com/cktan/tomlc99
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#Requires AutoHotkey v2.0
#Include "toml.ahk"

DllCall("AllocConsole")
global stdin := FileOpen("*", "r")
global stdout := FileOpen("*", "w")
global stderr := FileOpen("**", "w")
; global stderr := stdout

class Node {
    key := ""
    tab := 0
}

global stack := Array()
Loop 20 {
    stack.Push(Node())
}
global stacktop := 1 ; starts from 1 instead of 0
global indent := 0

prindent() {
    Loop indent {
        stdout.Write("  ")
    }
    stdout.Read(0)
}

print_timestamp(ts) {
    if ts.year_ptr() {
        stdout.Write(Format("{:04d}-{:02d}-{:02d}{}", ts.year, ts.month, ts.day, ts.hour_ptr() ? "T" : ""))
    }
    if ts.hour_ptr() {
        stdout.Write(Format("{:02d}:{:02d}:{:02d}", ts.hour, ts.minute, ts.second))
        if ts.millisec_ptr()
            stdout.Write(Format(".{:03d}", ts.millisec))
        if ts.z_ptr
            stdout.Write(ts.z)
    }
}

print_table(curtab) {
    global stdin, stdout, stderr
    global stack, stacktop, indent

    i := 0
    while p := toml_test_key_in(curtab, i++, &key) {
        if arr := toml_array_in(curtab, key) {
            prindent()
            stdout.WriteLine(key . " = [")
            stdout.Read(0)
            indent++
            print_array(arr)
            indent--
            prindent()
            stdout.WriteLine("],")
            stdout.Read(0)
            continue
        }

        if tab := toml_table_in(curtab, key) {
            stack[stacktop].key := key
            stack[stacktop].tab := tab
            stacktop++
            prindent()
            stdout.WriteLine(key . " = {")
            stdout.Read(0)
            indent++
            print_table(tab)
            indent--
            prindent()
            stdout.WriteLine("},")
            stdout.Read(0)
            stacktop--
            continue
        }

        d := toml_string_in(curtab, key)
        if d.ok {
            prindent()
            stdout.WriteLine(key . " = " . d.s . ",")
            stdout.Read(0)
            free(d.u)
            continue
        }

        d := toml_bool_in(curtab, key)
        if d.ok {
            prindent()
            stdout.WriteLine(key . " = " . (d.b ? "true," : "false,"))
            continue
        }

        d := toml_int_in(curtab, key)
        if d.ok {
            prindent()
            stdout.WriteLine(key . " = " . d.i . ",")
            stdout.Read(0)
            continue
        }

        d := toml_double_in(curtab, key)
        if d.ok {
            prindent()
            stdout.WriteLine(key . " = " . d.d . ",")
            stdout.Read(0)
            continue
        }

        d := toml_timestamp_in(curtab, key)
        if d.ok {
            prindent()
            stdout.Write(key . " = ")
            stdout.Read(0)
            print_timestamp(d.ts)
            stdout.WriteLine(",")
            stdout.Read(0)
            free(d.u)
            continue
        }

        stdout.Read(0)
        stderr.WriteLine("ERROR: unable to decode value in table")
        stderr.Read(0)
        Exit(1)
    }
}

print_array(curarr) {
    n := toml_array_nelem(curarr)

    loop n {
        i := A_Index - 1
        if arr := toml_array_at(curarr, i) {
            prindent()
            stdout.WriteLine("[")
            stdout.Read(0)
            indent++
            print_array(arr)
            indent--
            prindent()
            stdout.WriteLine("],")
            stdout.Read(0)
            continue
        }

        if tab := toml_table_at(curarr, i) {
            prindent()
            stdout.WriteLine("{")
            stdout.Read(0)
            indent++
            print_table(tab)
            indent--
            stdout.WriteLine("},")
            stdout.Read(0)
            continue
        }

        d := toml_string_at(curarr, i)
        if d.ok {
            prindent()
            stdout.WriteLine(d.s . ",")
            stdout.Read(0)
            free(d.u)
            continue
        }

        d := toml_bool_at(curarr, i)
        if d.ok {
            prindent()
            stdout.WriteLine(d.b ? "true," : "false,")
            stdout.Read(0)
            continue
        }

        d := toml_int_at(curarr, i)
        if d.ok {
            prindent()
            stdout.WriteLine(d.i . ",")
            stdout.Read(0)
            continue
        }

        d := toml_double_at(curarr, i)
        if d.ok {
            prindent()
            stdout.WriteLine(d.d . ",")
            stdout.Read(0)
            continue
        }

        d := toml_timestamp_at(curarr, i)
        if d.ok {
            prindent()
            print_timestamp(d.ts)
            stdout.WriteLine(",")
            stdout.Read(0)
            free(d.u)
            continue
        }

        stdout.Read(0)
        stderr.WriteLine("ERROR: unable to decode value in array")
        stderr.Read(0)
        Exit(1)
    }
}

cat(file_object) {
    global stdin, stdout, stderr
    global stack, stacktop, indent
    tab := toml_parse_file(file_object, &err)
    if not tab {
        stderr.WriteLine("ERROR: " . err)
        stderr.Read(0)
        return
    }

    stack[stacktop].tab := tab
    stack[stacktop].key := ""
    stacktop++
    stdout.WriteLine("{")
    stdout.Read(0)
    indent++
    print_table(tab)
    indent--
    stdout.WriteLine("}")
    stdout.Read(0)
    stacktop--

    toml_free(tab)
}

main(args) {
    if args.Length == 0 {
        cat(stdin)
    } else {
        loop args.Length {
            try file_object := FileOpen(args[A_Index], "r")
            catch as e {
                stderr.WriteLine("ERROR: cannot open " . args[A_Index] . ": " . e.Message)
                stderr.Read(0)
                Exit(1)
            }
            cat(file_object)
            file_object.Close()
        }
    }
    DllCall("ucrtbase\system", "AStr", "pause", "CDecl")
    Exit()
}

main(A_Args)
