module MdfReader
import InteractiveUtils.subtypes
export MDF
export read

struct CHAR
    x::UInt8
end
struct nCHAR{n}
    chars::NTuple{n,CHAR}
end
function Base.convert(::Type{NTuple{N,CHAR}},str::AbstractString) where N
    @assert N==length(str) "string must have length $N"
    NTuple{N,CHAR}(CHAR(c) for c in str)
end
nCHAR(str::AbstractString) = nCHAR{length(str)}(str)
Base.Char(c::CHAR) = Base.Char(c.x)

Base.show(io::IO, c::CHAR) = print(io, Char(c))
Base.string(c::nCHAR{x}) where {x} = join(Char.(c.chars))
Base.show(io::IO, c::nCHAR{x}) where {x} = print(io, string(c))
function Base.convert(::Type{nCHAR{N}},str::AbstractString) where {N}
    nCHAR{length(str)}(str)
end



struct BOOL
    x::UInt16
end
struct REAL
    x::Float64
end
struct LINK
    target::UInt32
end
isnill(b::LINK) = iszero(b.target)
Base.convert(::Type{LINK}, x::Int64) = LINK(x)
Base.show(io::IO, b::LINK) = print(io, "byteNr: $(b.target)")
Base.seek(io::IO, b::LINK) = seek(io, b.target)


struct BlockHeader
    type::nCHAR{2}
    size::UInt16
    function BlockHeader(t,s)
        @assert isBlockType(t) "$t is not a valid block type"
        new(t,s)
    end
end

Base.string(hd::BlockHeader) = string(hd.type)
typestr(hd) = uppercase(string(hd)) * "BLOCK"

abstract type BLOCK end
header(b::BLOCK) = b.header

struct IDBLOCK <: BLOCK
    fileIdentifier::nCHAR{8}
    formatIdentifier::nCHAR{8}
    programIdentifier::nCHAR{8}
    defaultByteOrder::UInt16
    defaultFloatingPointFormat::UInt16
    versionNumber::UInt16
    codePageNumber::UInt16
    reserved::nCHAR{28}
    standardFlags::UInt16
    customFlags::UInt16
    IDBLOCK() = new()
end

struct HDBLOCK <: BLOCK
    header::BlockHeader
    dataGroupBlock::LINK
    fileComment::LINK
    programBlock::LINK
    numberDataGroups::UInt16
    date::nCHAR{10}
    time::nCHAR{8}
    author::nCHAR{32}
    organization::nCHAR{32}
    project::nCHAR{32}
    subject::nCHAR{32}
    timeStamp::UInt64
    utcTimeOffset::Int16
    timeQuality::UInt16
    timerIdentification::nCHAR{32}
    HDBLOCK() = new()
end

struct DGBLOCK <: BLOCK
    header::BlockHeader
    nextDataGroupBlock::LINK
    firstChannelGroupBlock::LINK
    triggerBlock::LINK
    dataBlock::LINK
    numberChannelGroups::UInt16
    numverRecordIDs::UInt16
    Reserved::UInt32
    DGBLOCK() = new()
end

struct CGBLOCK <: BLOCK
    header::BlockHeader
    nextChannelGroupBlock::LINK
    firstChannelBlock::LINK
    comment::LINK
    recordID::UInt16
    numberChannels::UInt16
    sizeDataRecord::UInt16
    numberRecords::UInt32
    firstSampleReductionBlock::LINK
    CGBLOCK() = new()
end

struct CNBLOCK <: BLOCK
    header::BlockHeader
    nextChannelBlock::LINK
    conversionFormula::LINK
    sourceDependingExtension::LINK
    dependencyBlock::LINK
    comment::LINK
    channelType::UInt16
    shortSignalName::nCHAR{32}
    signalDescription::nCHAR{128}
    startOffset::UInt16
    numberOfBits::UInt16
    signalDataType::UInt16
    valueRangeValid::UInt16
    minimumSignalValue::REAL
    maximumSignalValue::REAL
    samplingRate::REAL
    longSignalName::LINK
    displayName::LINK
    additionalByteOffset::UInt16
    CNBLOCK() = new()
end

struct TXBLOCK <: BLOCK
    header::BlockHeader
    text::String
    TXBLOCK() = new()
end
struct PRBLOCK <: BLOCK
    header::BlockHeader
    text::String
    PRBLOCK() = new()
end
function Base.read(io::IO, b::Union{TXBLOCK,PRBLOCK})
    hd = read(io, BlockHeader)
    nb = size(hd) - sizeof(hd)
    str = String(Char.(read(io, nb)))
end

# TODO: make read block such that it only reads the blocksize number of
# fields and makes the other fields without content. (e.g. zero)

linkfields(b::DataType) =
    [fieldname(b, i) for i in 1:fieldcount(b) if fieldtype(b, i) == LINK]
linkfields(b) = linkfields(typeof(b))
type(hd) = eval(Symbol(typestr(hd)))
isBlockType(hd) = isdefined(@__MODULE__,Symbol(typestr(hd))) && (type(hd) in subtypes(BLOCK))




"""
	linkoffset(b)

returns the link field offset for the given block type
"""
function linkoffset(b::Type{T}) where {T<:BLOCK}
    [fieldoffset(b, i) for i in 1:fieldcount(b) if fieldtype(b, i) == LINK]
end

function readlink(io, pos)
    seek(io, pos)
    read(io, LINK)
end
function readlinks(io, hd)
    sz = sizeof(hd)
    loffs = linkoffset(type(hd))
    pos = loffs .+ position(io) .- sz
    links = [readlink(io, p) for p in pos]
end
Base.size(hd::BlockHeader) = hd.size

type(b::BLOCK) = type(header(b))


Base.read(io::IO, d::BlockHeader) = Base.read(io,type(d),size(d))

function Base.read(io::IO, d::Type{T}, size=packed_sizeof(d)) where {T<:Union{BLOCK,BlockHeader}}
    a = Type{d}()
    ptr = Ptr{UInt8}(pointer_from_objref(a))
    unsafe_copyto!()
    read!(io,a)
    a[]
end
zero
function zero!(p::Ptr{T}) where T
    nb = sizeof(T)
    puint = Ptr{UInt8}(p)
    unsafe_copyto!()
end
Base.show(io::IO, b::BlockHeader) = print(io, "Block
      type: $(typestr(b))
      size: $(size(b))
    ")

## next functions for iterating over linked blocks
next(b::DGBLOCK) = b.nextDataGroupBlock
next(b::CGBLOCK) = b.nextChannelGroupBlock
next(b::CNBLOCK) = b.nextChannelBlock
first(b::HDBLOCK) = b.dataGroupBlock
first(b::DGBLOCK) = b.firstChannelGroupBlock
first(b::CGBLOCK) = b.firstChannelBlock

struct MDF
    identifier
    header
    dataGroups
    channelGroups
    channels
end
function readBlock(io,T)
    hd = read(io, BlockHeader)
    skip(io, -sizeof(hd))
    @assert isBlockType(hd) "blocktype $(hd.type) is not valid"
    sz = size(hd)
    b  = read(io, type(hd), sz) # call a sized block reader
end
function readBlock(io,T, link::LINK)
    seek(io, link)
    readBlock(io,T)
end
function readGroup(io, start, T)
    b = readBlock(io,T, start)
    blocks = Array{T,1}(undef, 0)
    push!(blocks,b)
    nextBlock = next(b)
    while ~isnill(nextBlock)
        b = readBlock(io,T, nextBlock)
        push!(blocks, b)
        nextBlock = next(b)
    end
    blocks
end

function MDF(filepath)
    open(filepath) do io
        id = read(io, IDBLOCK)
        hd = read(io, HDBLOCK)
        dgblocks = readGroup(io, first(hd), DGBLOCK)
        cgblocks = [readGroup(io, first(dg), CGBLOCK) for dg in dgblocks]
        cnblocks = [readGroup(io, first(cg), CNBLOCK) for cgs in cgblocks for cg in cgs]
        MDF(id, hd, dgblocks, cgblocks, cnblocks)
    end
end

end
