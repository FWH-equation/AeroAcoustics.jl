using Test
using AeroAcoustics, HDF5
import DSP

@testset "Test 1: Monopole source without flow:" begin
    csm_ref = h5open("data/test1_csm.h5", "r") do file
        read(file, "CsmData/csmReal")+im*read(file, "CsmData/csmImag")
    end
    t = h5open("data/test1_timeseries.h5", "r") do file
        read(file, "MicrophoneData/microphoneDataPa")
    end

    # Test csm
    fs = h5readattr("data/test1_csm.h5", "CsmData")["fs"]
    n = h5readattr("data/test1_csm.h5", "CsmData")["n"]
    @timeit "compute csm" csm_test = csm(t;n=n,noverlap=div(n,2),fs=fs,win=DSP.hanning(n))
    @test csm_test.arr ≈ csm_ref

    # Setup beamforming
    fc2 = h5read("data/test1_csm.h5", "CsmData")["binCenterFrequenciesHz"]
    @test csm_test.fc==fc2
    z0 = h5readattr("data/test1_csm.h5", "CsmData")["z0"]
    micgeom = h5read("data/test1_csm.h5", "CsmData")["arrayGeom"]
    @test size(micgeom) == (3,84)

    @timeit "compute env" env = Environment(z0=z0,
                      micgeom=micgeom,
                      flim=(100,10000),
                      Nx = 21,
                      Ny = 21,
                      xlim=(-0.5,0.5),
                      ylim=(-0.5,0.5),
                      CSM=csm_test)

    @timeit "compute steeringvec" steeringvectors!(env)
    @timeit "compute beamforming" b = beamforming(env)
    idx = 10 # Frequency index
    s1,p1 = findmax(reshape(b[:,idx],21,21))
    bmax = ceil(SPL(s1))
    @test bmax == 47
    @test p1.I == (10,13)
    @timeit "compute psf" p_10 = psf(env)[:,idx]
    s2,p2 = findmax(reshape(p_10,21,21))
    @test ceil(SPL(sqrt(2).*s2)) == 94
    @test p2.I == (11,11)
    pcol_10 = zeros(env.N)
    @timeit "compute psf_col" AeroAcoustics.psf_col!(pcol_10,env.steeringvec.arr[:,:,10],floor(Int,env.N/2)+1)
    @test pcol_10 ≈ p_10
    # DAMAS
    x = zeros(size(b,1))
    @timeit "DAMAS single freq" damas!(x, env, b, env.fn[idx]; maxiter = 10)
    id1,id2 = UnitRange.(p1.I.-2,p1.I.+2)
    rdx = range(1;length=env.Nx)
    rdy = range(1;length=env.Ny)
    I = LinearIndices((rdx,rdy))[CartesianIndex.(id1,id2)]
    @test abs.(bmax-SPL.(sum(x[I]))) <= 1 # Within 1dB of beamforming is OK
end
