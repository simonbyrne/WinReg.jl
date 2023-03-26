# WinReg.jl

[![CI](https://github.com/simonbyrne/WinReg.jl/actions/workflows/test.yml/badge.svg)](https://github.com/simonbyrne/WinReg.jl/actions/workflows/test.yml)

Julia interface to the Windows Registry.

## Usage

The nomenclature of the Windows Registry is a bit confusing: a _registry key_ is a container object in a tree. Each registry key can itself have subkeys (so the keys form a hierarchy), but can also have _values_ which are really key-value pairs (usually referred to as _value names_ and _value data_).

In WinReg.jl, a registry key is represented by a `RegKey` object. There are several pre-defined root `RegKey`s:
 * `WinReg.HKEY_CLASSES_ROOT`
 * `WinReg.HKEY_CURRENT_USER`
 * `WinReg.HKEY_LOCAL_MACHINE`
 * `WinReg.HKEY_USERS`
 * `WinReg.HKEY_PERFORMANCE_DATA`
 * `WinReg.HKEY_CURRENT_CONFIG`
 * `WinReg.HKEY_DYN_DATA`


`WinReg.openkey(basekey, path)` opens a subkey of `basekey` at `path`, returning a `RegKey` object.

`subkeys(key)` gives an iterator over the names of the subkeys of `key`.

A `RegKey` acts like a `Dict` for the registry values: values can be read from the registry by `getindex`, existence checked by `haskey`, etc. Writing values (`setindex!`) is _not_ currently supported (see Requests below).

For convenience, the function `querykey` can be used to query a single value:

```julia
querykey(base, path, valuename)
```

### Example

```julia
using WinReg

key = openkey(WinReg.HKEY_LOCAL_MACHINE,"System\\CurrentControlSet\\Control\\Session Manager\\Environment")
arch = key["PROCESSOR_ARCHITECTURE"]

# or equivalently
arch = querykey(WinReg.HKEY_LOCAL_MACHINE,"System\\CurrentControlSet\\Control\\Session Manager\\Environment","PROCESSOR_ARCHITECTURE")
```

### Usage within a package

WinReg.jl should only be used on Windows OSes (though it is safe to load on other OSes). Suggested usage:

```julia
using WinReg # or import WinReg

if Sys.iswindows()
    # code calling WinReg functionality goes here
end
```

## Requests

If further functionality is required, please open an issue.
