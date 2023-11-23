/*
 * AutoHotkey wrapper of tomlc99
 * Copyright (c) 2023 Xuesong Peng <pengxuesong.cn@gmail.com>
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

global A_CharSize := 1
global A_IntSize := 4
global A_Int64Size := 8
global A_DoubleSize := 8
global A_IntPaddingSize := A_PtrSize - A_IntSize
global Toml_BufSize := 200

; An infrastructure class providing basic utilities
class TomlStruct extends Class {
    static c_str(val, encoding := "UTF-8") {
        buf := Buffer()
        if val {
            buf := Buffer(StrPut(val, encoding), 0)
            StrPut(val, buf, encoding)
        }
        return buf
    }
    static c_str_array(val_array, encoding := "UTF-8") {
        str_ptrs := Buffer((val_array.Length + 1) * A_PtrSize, 0)
        str_bufs := Array()
        for i, v in val_array {
            if not IsSet(v)
                break
            buff := TomlStruct.c_str(v, encoding)
            NumPut("Ptr", buff.Ptr, str_ptrs, (i - 1) * A_PtrSize)
            str_bufs.Push(buff)
        }
        return {
            ptrs: str_ptrs,
            bufs: str_bufs
        }
    }

    ; shallow copy
    copy(src) {
        tgt := this.struct_ptr()
        length := %Type(this)%.struct_size()
        if src and tgt and length > 0 {
            Loop length {
                byte := NumGet(src, A_Index - 1, "Char")
                NumPut("Char", byte, tgt, A_Index - 1)
            }
        }
    }
    num_get(offset := 0, type := "Int") {
        return NumGet(this.struct_ptr(), offset, type)
    }
    num_put(type := "Int", val := 0, offset := 0) {
        NumPut(type, val, this.struct_ptr(), offset)
    }
    ptr_get(offset := 0) {
        return NumGet(this.struct_ptr(), offset, "Ptr")
    }
    ptr_put(ptr := 0, offset := 0) {
        NumPut("Ptr", ptr, this.struct_ptr(), offset)
    }
    c_str_get(src := this.struct_ptr(), offset := 0, encoding := "UTF-8") {
        return (p := NumGet(src, offset, "Ptr")) ? StrGet(p, encoding) : ""
    }
    c_str_put(val, tgt := this.struct_ptr(), offset := 0, encoding := "UTF-8") {
        buf := TomlStruct.c_str(val, encoding)
        NumPut("Ptr", buf.Ptr, tgt, offset)
        return buf
    }
    c_str_array_get(offset, encoding := "UTF-8") {
        res := Array()
        if ptr := this.num_get(offset, "Ptr")
            Loop {
                if not val := this.c_str_get(ptr, (A_Index - 1) * A_PtrSize, encoding)
                    break
                res.Push(val)
            }
        return res
    }
    c_str_array_put(val_array, tgt := this.struct_ptr(), offset := 0, encoding := "UTF-8") {
        arr_buf := TomlStruct.c_str_array(val_array, encoding)
        NumPut("Ptr", arr_buf.ptrs.Ptr, tgt, offset)
        return arr_buf
    }
    struct_array_get(offset, length, struct) {
        res := Array()
        if ptr := this.num_get(offset, "Ptr")
            Loop length {
                res.Push(struct.Call(ptr + (A_Index - 1) * struct.struct_size()))
            }
        return res
    }
} ; TomlStruct

global toml_dll := DllCall("LoadLibrary", "Str", "toml.dll", "Ptr")
if not toml_dll
    throw Error("加载 Toml 动态库失败！")

global ucrt_dll := DllCall("LoadLibrary", "Str", "ucrtbase.dll", "Ptr")
free(block) {
    if not ucrt_dll
        return
    DllCall("ucrtbase\free", "Ptr", block, "CDecl")
}

/**
 * Parse a file. Return a table on success, or 0 otherwise.
 * Caller must toml_free(the-return-value) after use.
 * @param file_object AutoHotkey File object of toml format
 * @param err String by ref will contain the error message if any
 * @returns {Ptr} A pointer to `toml_table_t`
 */
toml_parse_file(file_object, &err := "") {
    content := file_object.Read()
    return toml_parse(content, &err)
}

/**
 * Parse a string containing the full config.
 * Return a table on success, or 0 otherwise.
 * Caller must toml_free(the-return-value) after use.
 * @param conf String conaining toml content
 * @param err String by ref will contain the error message if any
 * @returns {Ptr} A pointer to `toml_table_t`
 */
toml_parse(conf, &err := "") {
    errbuf := Buffer(Toml_BufSize, 0)
    if not tab := DllCall("toml\toml_parse", "Ptr", TomlStruct.c_str(conf).Ptr, "Ptr", errbuf.Ptr, "Int", Toml_BufSize, "CDecl Ptr")
        err := StrGet(errbuf.Ptr, "UTF-8")
    return tab
}

/**
 * Free the table returned by toml_parse() or toml_parse_file(). Once
 * this function is called, any handles accessed through this tab
 * directly or indirectly are no longer valid.
 * @param tab A pointer to `toml_table_t`
 */
toml_free(tab) {
    DllCall("toml\toml_free", "Ptr", tab, "CDecl Ptr")
}

/**
 * Timestamp types. The year, month, day, hour, minute, second, z
 * fields may be NULL if they are not relevant. e.g. In a DATE
 * type, the hour, minute, second and z fields will be NULLs.
 */
class TomlTimestamp extends TomlStruct {
    __New(ptr := 0) {
        this.buff := Buffer(TomlTimestamp.struct_size(), 0)
        this.copy(ptr)
        ; Deep copy
        local __buffer_ptr := this.struct_ptr() + TomlTimestamp.__buffer_offset()
        if this.year_ptr()
            this.ptr_put(__buffer_ptr + TomlTimestamp.__buffer.year_offset(), TomlTimestamp.year_offset())
        if this.month_ptr()
            this.ptr_put(__buffer_ptr + TomlTimestamp.__buffer.month_offset(), TomlTimestamp.month_offset())
        if this.day_ptr()
            this.ptr_put(__buffer_ptr + TomlTimestamp.__buffer.day_offset(), TomlTimestamp.day_offset())
        if this.hour_ptr()
            this.ptr_put(__buffer_ptr + TomlTimestamp.__buffer.hour_offset(), TomlTimestamp.hour_offset())
        if this.minute_ptr()
            this.ptr_put(__buffer_ptr + TomlTimestamp.__buffer.minute_offset(), TomlTimestamp.minute_offset())
        if this.second_ptr()
            this.ptr_put(__buffer_ptr + TomlTimestamp.__buffer.second_offset(), TomlTimestamp.second_offset())
        if this.millisec_ptr()
            this.ptr_put(__buffer_ptr + TomlTimestamp.__buffer.millisec_offset(), TomlTimestamp.millisec_offset())
        if this.z_ptr()
            this.ptr_put(__buffer_ptr + TomlTimestamp.__buffer.z_offset(), TomlTimestamp.z_offset())
    }

    class __buffer {
        static year_offset := (*) => 0
        static month_offset := (*) => TomlTimestamp.__buffer.year_offset() + A_IntSize
        static day_offset := (*) => TomlTimestamp.__buffer.month_offset() + A_IntSize
        static hour_offset := (*) => TomlTimestamp.__buffer.day_offset() + A_IntSize
        static minute_offset := (*) => TomlTimestamp.__buffer.hour_offset() + A_IntSize
        static second_offset := (*) => TomlTimestamp.__buffer.minute_offset() + A_IntSize
        static millisec_offset := (*) => TomlTimestamp.__buffer.second_offset() + A_IntSize
        static z_offset := (*) => TomlTimestamp.__buffer.millisec_offset() + A_IntSize
        static struct_size := (*) => TomlTimestamp.__buffer.z_offset() + A_CharSize * 12 ; including 2-byte padding
    }

    static __buffer_offset := (*) => 0
    static year_offset := (*) => TomlTimestamp.__buffer.struct_size()
    static month_offset := (*) => TomlTimestamp.year_offset() + A_PtrSize
    static day_offset := (*) => TomlTimestamp.month_offset() + A_PtrSize
    static hour_offset := (*) => TomlTimestamp.day_offset() + A_PtrSize
    static minute_offset := (*) => TomlTimestamp.hour_offset() + A_PtrSize
    static second_offset := (*) => TomlTimestamp.minute_offset() + A_PtrSize
    static millisec_offset := (*) => TomlTimestamp.second_offset() + A_PtrSize
    static z_offset := (*) => TomlTimestamp.millisec_offset() + A_PtrSize
    static struct_size := (*) => TomlTimestamp.z_offset() + A_PtrSize

    struct_ptr := (*) => this.buff.Ptr

    year_ptr := (*) => this.ptr_get(TomlTimestamp.year_offset())
    month_ptr := (*) => this.ptr_get(TomlTimestamp.month_offset())
    day_ptr := (*) => this.ptr_get(TomlTimestamp.day_offset())
    year {
        get => (p := this.year_ptr()) ? NumGet(p, "Int") : 0
    }
    month {
        get => (p := this.month_ptr()) ? NumGet(p, "Int") : 0
    }
    day {
        get => (p := this.day_ptr()) ? NumGet(p, "Int") : 0
    }

    hour_ptr := (*) => this.ptr_get(TomlTimestamp.hour_offset())
    minute_ptr := (*) => this.ptr_get(TomlTimestamp.minute_offset())
    second_ptr := (*) => this.ptr_get(TomlTimestamp.second_offset())
    millisec_ptr := (*) => this.ptr_get(TomlTimestamp.millisec_offset())
    hour {
        get => (p := this.hour_ptr()) ? NumGet(p, "Int") : 0
    }
    minute {
        get => (p := this.minute_ptr()) ? NumGet(p, "Int") : 0
    }
    second {
        get => (p := this.second_ptr()) ? NumGet(p, "Int") : 0
    }
    millisec {
        get => (p := this.millisec_ptr()) ? NumGet(p, "Int") : 0
    }

    z_ptr := (*) => this.ptr_get(TomlTimestamp.z_offset())
    z {
        get => this.c_str_get(, TomlTimestamp.z_offset())
    }
} ; TomlTimestamp

/*-----------------------------------------------------------------
 *  Enhanced access methods
 */

class TomlDatum extends TomlStruct {
    __New(ptr := 0) {
        this.buff := Buffer(TomlDatum.struct_size(), 0)
        this.copy(ptr)
    }

    static ok_offset := (*) => 0
    static u_offset := (*) => TomlDatum.ok_offset() + A_IntSize + A_IntPaddingSize
    static struct_size := (*) => TomlDatum.u_offset() + A_PtrSize

    struct_ptr := (*) => this.buff.Ptr

    ok {
        get => this.num_get(TomlDatum.ok_offset())
    }

    ; address of the union. free this field instead of ts / s
    u {
        get => this.ptr_get(TomlDatum.u_offset())
    }
    ; u must be freed after use ts
    ts {
        get => this.u ? TomlTimestamp(this.u) : 0
    }
    ; string value. u must be freed after use s
    s {
        get => this.c_str_get(, TomlDatum.u_offset())
    }
    ; bool value
    b {
        get => this.num_get(TomlDatum.u_offset())
    }
    ; int value
    i {
        get => this.num_get(TomlDatum.u_offset(), "Int64")
    }
    ; double value
    d {
        get => this.num_get(TomlDatum.u_offset(), "Double")
    }
} ; TomlDatum

/* on arrays: */
/**
 * retrieve size of array.
 * @param arr pointer to `toml_array_t`
 * @returns {number} the size of the array
 */
toml_array_nelem(arr) {
    return DllCall("toml\toml_array_nelem", "Ptr", arr, "CDecl Int")
}

/* ... retrieve values using index. */
; do not directly use
toml_val_at(type, arr, idx) {
    datum := TomlDatum()
    DllCall("toml\toml_" . type . "_at", "Ptr", datum.struct_ptr(), "Ptr", arr, "Int", idx, "CDecl")
    return datum
}
/**
 * @param arr pointer to `toml_array_t`
 * @param idx index in the array, starting from 0
 * @returns {TomlDatum} the datum of String at the index in the array
 */
toml_string_at(arr, idx) {
    return toml_val_at("string", arr, idx)
}
/**
 * @param arr pointer to `toml_array_t`
 * @param idx index in the array, starting from 0
 * @returns {TomlDatum} the datum of Bool at the index in the array
 */
toml_bool_at(arr, idx) {
    return toml_val_at("bool", arr, idx)
}
/**
 * @param arr pointer to `toml_array_t`
 * @param idx index in the array, starting from 0
 * @returns {TomlDatum} the datum of Integer at the index in the array
 */
toml_int_at(arr, idx) {
    return toml_val_at("int", arr, idx)
}
/**
 * @param arr pointer to `toml_array_t`
 * @param idx index in the array, starting from 0
 * @returns {TomlDatum} the datum of Double at the index in the array
 */
toml_double_at(arr, idx) {
    return toml_val_at("double", arr, idx)
}
/**
 * @param arr pointer to `toml_array_t`
 * @param idx index in the array, starting from 0
 * @returns {TomlDatum} the datum of timestamp at the index in the array
 */
toml_timestamp_at(arr, idx) {
    return toml_val_at("timestamp", arr, idx)
}

/* ... retrieve array or table using index. */
; do not directly use
toml_ptr_at(type, arr, idx) {
    return DllCall("toml\toml_" . type . "_at", "Ptr", arr, "Int", idx, "CDecl Ptr")
}
toml_array_at(arr, idx) {
    return toml_ptr_at("array", arr, idx)
}
toml_table_at(arr, idx) {
    return toml_ptr_at("table", arr, idx)
}

/* on tables: */
/**
 * Retrieve the key in table at keyidx.
 * - Recommend to use `toml_test_key_in` instead
 * @param tab pointer to `toml_table_t`
 * @param keyidx index of key, starting from 0
 * @returns {String} the retrived key (may be empty), or empty string if out of range
 */
toml_key_in(tab, keyidx) {
    p := DllCall("toml\toml_key_in", "Ptr", tab, "Int", keyidx, "CDecl Ptr")
    return p ? StrGet(p, "UTF-8") : ""
}
/**
 * Test and retrieve the key in table at keyindex. Return 0 if out of range
 * @param tab pointer to `toml_table_t`
 * @param keyidx index of key, starting from 0
 * @param str store the key string if exists
 * @returns {Ptr} the pointer to key's C string, or 0 if out of range
 */
toml_test_key_in(tab, keyidx, &str := "") {
    if p := DllCall("toml\toml_key_in", "Ptr", tab, "Int", keyidx, "CDecl Ptr")
        str := StrGet(p, "UTF-8")
    return p
}
/**
 * Test if key exists in table
 * @param tab pointer to `toml_table_t`
 * @param key String of key
 * @returns {number} 1 if key exists in tab, 0 otherwise
 */
toml_key_exists(tab, key) {
    return DllCall("toml\toml_key_exists", "Ptr", tab, "Ptr", TomlStruct.c_str(key).Ptr, "CDecl Int")
}

/* ... retrieve values using key. */
; do not directly use
toml_val_in(type, tab, key) {
    datum := TomlDatum()
    DllCall("toml\toml_" . type . "_in", "Ptr", datum.struct_ptr(), "Ptr", tab, "Ptr", TomlStruct.c_str(key).Ptr, "CDecl")
    return datum
}
/**
 * @param tab pointer to `toml_table_t`
 * @param key String of key
 * @returns {TomlDatum} the String datum of key in the table
 */
toml_string_in(tab, key) {
    return toml_val_in("string", tab, key)
}
/**
 * @param tab pointer to `toml_table_t`
 * @param key String of key
 * @returns {TomlDatum} the Bool datum of key in the table
 */
toml_bool_in(tab, key) {
    return toml_val_in("bool", tab, key)
}
/**
 * @param tab pointer to `toml_table_t`
 * @param key String of key
 * @returns {TomlDatum} the Integer datum of key in the table
 */
toml_int_in(tab, key) {
    return toml_val_in("int", tab, key)
}
/**
 * @param tab pointer to `toml_table_t`
 * @param key String of key
 * @returns {TomlDatum} the Double datum of key in the table
 */
toml_double_in(tab, key) {
    return toml_val_in("double", tab, key)
}
/**
 * @param tab pointer to `toml_table_t`
 * @param key String of key
 * @returns {TomlDatum} the timestamp datum of key in the table
 */
toml_timestamp_in(tab, key) {
    return toml_val_in("timestamp", tab, key)
}

/* .. retrieve array or table using key. */
; do not directly use
toml_ptr_in(type, tab, key) {
    return DllCall("toml\toml_" . type . "_in", "Ptr", tab, "Ptr", TomlStruct.c_str(key).Ptr, "CDecl Ptr")
}
toml_array_in(tab, key) {
    return toml_ptr_in("array", tab, key)
}
toml_table_in(tab, key) {
    return toml_ptr_in("table", tab, key)
}

/*-----------------------------------------------------------------
 * lesser used
 */

/* Return the array kind: 't'able, 'a'rray, 'v'alue, 'm'ixed */
toml_array_kind(arr) {
    return Chr(DllCall("toml\toml_array_kind", "Ptr", arr, "CDecl Char"))
}

/* For array kind 'v'alue, return the type of values
   i:int, d:double, b:bool, s:string, t:time, D:date, T:timestamp, 'm'ixed
   0 if unknown
*/
toml_array_type(arr) {
    return (c := DllCall("toml\toml_array_type", "Ptr", arr, "CDecl Char")) ? Chr(c) : 0
}

/* Return the key of an array */
toml_array_key(arr) {
    return (p := DllCall("toml\toml_array_key", "Ptr", arr, "CDecl Ptr")) ? StrGet(p, "UTF-8") : ""
}

/* Return the number of key-values in a table */
toml_table_nkval(tab) {
    return DllCall("toml\toml_table_nkval", "Ptr", tab, "CDecl Int")
}

/* Return the number of arrays in a table */
toml_table_narr(tab) {
    return DllCall("toml\toml_table_narr", "Ptr", tab, "CDecl Int")
}

/* Return the number of sub-tables in a table */
toml_table_ntab(tab) {
    return DllCall("toml\toml_table_ntab", "Ptr", tab, "CDecl Int")
}

/* Return the key of a table*/
toml_table_key(tab) {
    return (p := DllCall("toml\toml_table_key", "Ptr", tab, "CDecl Ptr")) ? StrGet(p, "UTF-8") : ""
}

/*--------------------------------------------------------------
 * misc
 */
/* Set customized `malloc` and `free` function */
toml_set_memutil(xxmalloc, xxfree) {
    DllCall("toml\toml_set_memutil", "Ptr", xxmalloc, "Ptr", xxfree, "CDecl")
}
