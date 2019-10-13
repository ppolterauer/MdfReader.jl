module mdfReader

function open(filename)
    io = Base.open(filename)
    return io
end

abstract type BLOCK end
struct IDBLOCK <: BLOCK
    fileIdentifier
    formatIdentifier
    programIdentifier
    defaultByteOrder
    defaultFloatingPointFormat
    versionNumber
    codePageNumber
    standardFlags
    customFlags
end

function readIDBlock(io)
    fId = Base.read(io)
end # modul
