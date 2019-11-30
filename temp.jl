using MdfReader
const m = MdfReader
path = "test\\testfiles\\test.mdf"
# mdf = MDF(path)

##


##
# abstract type bitstypes end
# struct bittype <: bitstypes end
# struct nonbittype <: bitstypes end
# # nameing is stolen from StructIO.jl
# bitstypes(a::DataType) = isbitstype(a) ? bittype : nonbittype


##
a = m.BlockHeader("HD",100)


##

# function Base.read(io,a::Union{Type{BLOCK},Type{MdfReader.BlockHeader}},

a = HDBLOCK()
pointer(a::BLOCK) = convert(Ptr{typeof(a)},pointer_from_objref(Ref{a}))
p = pointer(a)
padding = Base.padding(a)
