function beamformer_old{T,C}(
    Nx::Int64,
    Ny::Int64,
    X::Array{T,2},
    Y::Array{T,2},
    z0::T,
    f::T,
    rn::Array{T,2},
    CSM::Array{C,2};
    psf::Bool=false)

    const M = size(rn,1)           # Number of microphones
    const c::Float64 = 343.0       # Speed of sound
    const kw::T = 2pi*f/c          # wavenumber
    # CSM[eye(Bool,M)] = 0;        # Naive diagonal removal

    # Allocation of arrays
    gj = Array{C}(M)
    gjs = Array{C}(Nx,Ny,M)
    b = Array{T}(Nx,Ny)

    # Compute transfer functions
    Threads.@threads for i in 1:Nx
        for j in 1:Ny
            r0::Float64 = sqrt(X[i,j]^2 + Y[i,j]^2 + z0^2)
            #rsum = 0.0 # Type III Steering vector
            for m in 1:M
                rm::Float64 = sqrt((X[i,j]-rn[m,1])^2+(Y[i,j]-rn[m,2])^2 + z0^2)
                #gj[m] = exp(-im*kw*(rm-r0)) # TYPE I Steering vector
                gj[m] = (1/M)*(rm/r0)*exp(-im*kw*(rm-r0)) # TYPE II Steering vector
                #gj[m] = (1/(r0*rm))*exp(-im*kw*(rm-r0)) # TYPE III Steering vector
                #rsum += 1/rm^2
            end
            #gj *= 1/rsum # Type III Steering vector
            gjs[i,j,:] = gj
            b[i,j] = real(gj'*CSM*gj)
        end
    end


    if psf
        PSF = Array{T}(Nx,Ny)
        grs = Array{C}(M)
        midx::Int64 = 0
        midy::Int64 = 0
        if iseven(Nx)
            midx = Nx/2
        elseif isodd(Nx)
            midx = round(Int64,Nx/2)+1
        end
        if iseven(Ny)
            midy = Ny/2
        elseif isodd(Ny)
            midy = round(Int64,Ny/2)+1
        end
        grs = vec(gjs[midx,midy,:])
        Threads.@threads for i in 1:Nx
            for j in 1:Ny
                #PSF[i,j] = abs(vec(gjs[i,j,:])'*grs*grs'*vec(gjs[i,j,:]))/M^2
                PSF[i,j] = M^2*abs(vec(gjs[i,j,:])'*grs)^2 # Needs to multiply with (r0/rm)^2 to correct level
            end
        end
        return b,gjs,PSF
    else
        return b,gjs
    end
end

function beamformer_old{T,C}(
    Nx::Int64,
    Ny::Int64,
    X::Array{T,2},
    Y::Array{T,2},
    z0::T,
    f::Array{T,1},
    rn::Array{T,2},
    CSM::Array{C,3};
    psf::Bool=false)

    const M = size(rn,1)    # Number of microphones
    Nf = length(f)
    b = Array{T}(Nx,Ny,Nf)
    gjs = Array{C}(Nx,Ny,M,Nf)
    if psf
        PSF = Array{T}(Nx,Ny,Nf)
        Threads.@threads for i in 1:Nf
            b[:,:,i],gjs[:,:,:,i],PSF[:,:,i] = beamformer(Nx,Ny,X,Y,z0,f[i],rn,CSM[i,:,:];psf=true)
        end
        return b,gjs,PSF
    else
        Threads.@threads for i in 1:Nf
            b[:,:,i],gjs[:,:,:,i] = beamformer(Nx,Ny,X,Y,z0,f[i],rn,CSM[i,:,:];psf=false)
        end
        return b,gjs
    end

end