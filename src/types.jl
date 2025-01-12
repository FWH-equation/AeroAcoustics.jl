abstract type AeroAcousticType end

struct FreqArray{T, N, AA<:AbstractVector} <: AbstractArray{T, N}
    arr::Array{T, N}
    fc::AA
end

# Standard array functions and indexing
Base.size(A::FreqArray) = size(A.arr)
Base.axes(A::FreqArray) = axes(A.arr)
Base.getindex(A::FreqArray, i::Int) = A.arr[i]
Base.getindex(A::FreqArray{T, N}, I::Vararg{Int, N}) where {T, N} = A.arr[I...]

"""
    Environment

The Environment struct is required for most methods and defines the geometrical
setup, constants, and stores the relevant data together. The fields are

# Arguments

*Required:*

- `micgeom::Array{T,2}`: (x,y,z) coordinates for microhone array.
- `z0::Real`: distance to source plane from microphone array.
- `CSM::FreqArray`: Cross-spectral matrix, size `M x M x Nf`, where `M` is the number of microphones and `Nf` is the number of frequency bins.

*Optional:*

- `flim::Tuple=extrema(CSM.fc)`: Frequency limits (fmin,fmax).
- `Nx::Integer=21`: Number of computational gridpoint in x direction.
- `Ny::Integer=21`: Number of computational gridpoint in y direction.
- `xlim::Tuple=(-1.,1.)`: Cartesian x-coordinate limits.
- `ylim::Tuple=(-1.,1.)`: Cartesian y-coordinate limits.
- `c::Real=343.`: Speed of sound [m/s].
- `Ma::Real=0.0`: Mach number.
- `h::Real=0.0`: Distance to shear layer (Amiet correction) should be supplied when `Ma != 0`.
"""
@with_kw mutable struct Environment <: AeroAcousticType
    micgeom::Matrix{<:AbstractFloat}
    z0::Real
    CSM::FreqArray
    flim::NTuple{2,Real} = extrema(CSM.fc)
    Nx::Int = 21
    Ny::Int = 21
    xlim::NTuple{2,Real} = (-1.,1.)
    ylim::NTuple{2,Real} = (-1.,1.)
    shear::Bool = false
    c::Real = 343.0 # Speed of sound
    Ma::Real = 0.0 # Flow Mach speed TODO: Generalize to NTuple{3,Real}
    h::Real = 0.0 # Distance to shear layer (used for Shear layer correction)
    ### Compute extra parameters
    Cinds = (CSM.fc.>=flim[1]) .& (CSM.fc.<=flim[2])
    fn = CSM.fc[Cinds]
    M::Int = size(micgeom,2)
    Nf::Int = length(fn)
    N = Nx*Ny
    rx = range(xlim[1],stop = xlim[2], length = Nx)
    ry = range(ylim[1],stop = ylim[2], length = Ny)
    Rxy = hcat([[x, y, z] for x in rx, y in ry, z in z0]...)
    D0 = colwise(Euclidean(), Rxy, [0,0,0]) # Distance from center of array to grid points
    D = pairwise(Euclidean(), Rxy, micgeom; dims=2) # Distance from each mic to grid points
    steeringvec = nothing
end
