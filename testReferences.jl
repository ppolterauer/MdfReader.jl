## playing around with references
struct Byte8
    a :: NTuple{8,UInt8}
end
struct Byte44
    a :: NTuple{4,UInt8}
    b :: NTuple{4,UInt8}
end
struct Byte4864
    d :: UInt8
    c :: UInt64
    a :: NTuple{4,UInt8}
    b :: NTuple{8,UInt8}
end

a   = Ref(Byte8(NTuple{8,UInt8}(1:8)))
b   = Ref(Byte44(NTuple{4,UInt8}(1:4),NTuple{4,UInt8}(1:4)))
c   = Ref(Byte4864(1,0x9900,NTuple{4,UInt8}(1:4),NTuple{8,UInt8}(1:8)))
pa  = Ptr{UInt8}(pointer_from_objref(a))
pb  = Ptr{UInt8}(pointer_from_objref(b))
pc  = Ptr{UInt8}(pointer_from_objref(c))

@show Base.padding(Byte4864)
##
# unsafe_store!(p,UInt8(100),4)
@show a[]size
@show b[]

unsafe_copyto!(pb,pa,8)
@show a[]
@show b[]


##
unsafe_store!(pc,0xff,11); c[]

unsafe_read()
