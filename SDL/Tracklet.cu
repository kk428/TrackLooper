#ifdef __CUDACC__
#define CUDA_CONST_VAR __device__
#endif
#include "Tracklet.cuh"

#include "allocate.h"

CUDA_CONST_VAR float SDL::pt_betaMax = 7.0f;


void SDL::createTrackletsInUnifiedMemory(struct tracklets& trackletsInGPU, unsigned int maxTracklets, unsigned int nLowerModules,cudaStream_t stream)
{

    unsigned int nMemoryLocations = maxTracklets * nLowerModules;
#ifdef CACHE_ALLOC
//    cudaStream_t stream =0;
    trackletsInGPU.segmentIndices = (unsigned int*)cms::cuda::allocate_managed(nMemoryLocations * sizeof(unsigned int) * 2,stream);
    trackletsInGPU.lowerModuleIndices = (unsigned int*)cms::cuda::allocate_managed(nMemoryLocations * sizeof(unsigned int) * 4,stream);//split up to avoid runtime error of exceeding max byte allocation at a time
    trackletsInGPU.nTracklets = (unsigned int*)cms::cuda::allocate_managed(nLowerModules * sizeof(unsigned int),stream);
    trackletsInGPU.zOut = (float*)cms::cuda::allocate_managed(nMemoryLocations * sizeof(float) * 4,stream);
    trackletsInGPU.betaIn = (float*)cms::cuda::allocate_managed(nMemoryLocations * sizeof(float) * 3,stream);
#else
    cudaMallocManaged(&trackletsInGPU.segmentIndices, 2 * nMemoryLocations * sizeof(unsigned int));
    cudaMallocManaged(&trackletsInGPU.lowerModuleIndices, 4 * nMemoryLocations * sizeof(unsigned int));
    cudaMallocManaged(&trackletsInGPU.nTracklets,nLowerModules * sizeof(unsigned int));
    cudaMallocManaged(&trackletsInGPU.zOut, nMemoryLocations *4* sizeof(float));
    cudaMallocManaged(&trackletsInGPU.betaIn, nMemoryLocations *3* sizeof(float));

#ifdef CUT_VALUE_DEBUG
    cudaMallocManaged(&trackletsInGPU.zLo, nMemoryLocations * sizeof(float));
    cudaMallocManaged(&trackletsInGPU.zHi, nMemoryLocations * sizeof(float));
    cudaMallocManaged(&trackletsInGPU.zLoPointed, nMemoryLocations * sizeof(float));
    cudaMallocManaged(&trackletsInGPU.zHiPointed, nMemoryLocations * sizeof(float));
    cudaMallocManaged(&trackletsInGPU.sdlCut, nMemoryLocations * sizeof(float));
    cudaMallocManaged(&trackletsInGPU.betaInCut, nMemoryLocations * sizeof(float));
    cudaMallocManaged(&trackletsInGPU.betaOutCut, nMemoryLocations * sizeof(float));
    cudaMallocManaged(&trackletsInGPU.deltaBetaCut, nMemoryLocations * sizeof(float));
    cudaMallocManaged(&trackletsInGPU.rtLo, nMemoryLocations * sizeof(float));
    cudaMallocManaged(&trackletsInGPU.rtHi, nMemoryLocations * sizeof(float));
    cudaMallocManaged(&trackletsInGPU.kZ, nMemoryLocations * sizeof(float));

#endif
#endif
    trackletsInGPU.rtOut = trackletsInGPU.zOut + nMemoryLocations;
    trackletsInGPU.deltaPhiPos = trackletsInGPU.zOut + nMemoryLocations * 2;
    trackletsInGPU.deltaPhi = trackletsInGPU.zOut + nMemoryLocations * 3;
    trackletsInGPU.betaOut = trackletsInGPU.betaIn + nMemoryLocations;
    trackletsInGPU.pt_beta = trackletsInGPU.betaIn + nMemoryLocations * 2;
//#pragma omp parallel for
//    for(size_t i = 0; i<nLowerModules;i++)
//    {
//        trackletsInGPU.nTracklets[i] = 0;
//    }

    cudaMemsetAsync(trackletsInGPU.nTracklets,0,nLowerModules*sizeof(unsigned int),stream);
}
void SDL::createTrackletsInExplicitMemory(struct tracklets& trackletsInGPU, unsigned int maxTracklets, unsigned int nLowerModules,cudaStream_t stream)
{

    unsigned int nMemoryLocations = maxTracklets * nLowerModules;
#ifdef CACHE_ALLOC
//    cudaStream_t stream =0;
    int dev;
    cudaGetDevice(&dev);
    trackletsInGPU.segmentIndices = (unsigned int*)cms::cuda::allocate_device(dev,nMemoryLocations * sizeof(unsigned int) * 2,stream);
    trackletsInGPU.lowerModuleIndices = (unsigned int*)cms::cuda::allocate_device(dev,nMemoryLocations * sizeof(unsigned int) * 4,stream);//split up to avoid runtime error of exceeding max byte allocation at a time
    trackletsInGPU.nTracklets = (unsigned int*)cms::cuda::allocate_device(dev,nLowerModules * sizeof(unsigned int),stream);
    trackletsInGPU.zOut = (float*)cms::cuda::allocate_device(dev,nMemoryLocations * sizeof(float) * 4,stream);
    trackletsInGPU.betaIn = (float*)cms::cuda::allocate_device(dev,nMemoryLocations * sizeof(float) * 3,stream);
#else
    cudaMalloc(&trackletsInGPU.segmentIndices, 2 * nMemoryLocations * sizeof(unsigned int));
    cudaMalloc(&trackletsInGPU.lowerModuleIndices, 4 * nMemoryLocations * sizeof(unsigned int));
    cudaMalloc(&trackletsInGPU.nTracklets,nLowerModules * sizeof(unsigned int));
    cudaMalloc(&trackletsInGPU.zOut, nMemoryLocations *4* sizeof(float));
    cudaMalloc(&trackletsInGPU.betaIn, nMemoryLocations *3* sizeof(float));
#endif
    cudaMemsetAsync(trackletsInGPU.nTracklets,0,nLowerModules*sizeof(unsigned int),stream);
    trackletsInGPU.rtOut = trackletsInGPU.zOut + nMemoryLocations;
    trackletsInGPU.deltaPhiPos = trackletsInGPU.zOut + nMemoryLocations * 2;
    trackletsInGPU.deltaPhi = trackletsInGPU.zOut + nMemoryLocations * 3;
    trackletsInGPU.betaOut = trackletsInGPU.betaIn + nMemoryLocations;
    trackletsInGPU.pt_beta = trackletsInGPU.betaIn + nMemoryLocations * 2;
}

#ifdef CUT_VALUE_DEBUG
__device__ void SDL::addTrackletToMemory(struct tracklets& trackletsInGPU, unsigned int innerSegmentIndex, unsigned int outerSegmentIndex, unsigned int innerInnerLowerModuleIndex, unsigned int innerOuterLowerModuleIndex, unsigned int outerInnerLowerModuleIndex, unsigned int outerOuterLowerModuleIndex, float& zOut, float& rtOut, float& deltaPhiPos, float& deltaPhi, float& betaIn, float& betaOut, float pt_beta, float& zLo, float& zHi, float& rtLo, float& rtHi, float& zLoPointed, float&
        zHiPointed, float& sdlCut, float& betaInCut, float& betaOutCut, float& deltaBetaCut, float& kZ, unsigned int trackletIndex)
#else
__device__ void SDL::addTrackletToMemory(struct tracklets& trackletsInGPU, unsigned int innerSegmentIndex, unsigned int outerSegmentIndex, unsigned int innerInnerLowerModuleIndex, unsigned int innerOuterLowerModuleIndex, unsigned int outerInnerLowerModuleIndex, unsigned int outerOuterLowerModuleIndex, float& zOut, float& rtOut, float& deltaPhiPos, float& deltaPhi, float& betaIn, float& betaOut, float pt_beta, unsigned int trackletIndex)
#endif
{
    trackletsInGPU.segmentIndices[trackletIndex * 2] = innerSegmentIndex;
    trackletsInGPU.segmentIndices[trackletIndex * 2 + 1] = outerSegmentIndex;
    trackletsInGPU.lowerModuleIndices[trackletIndex * 4] = innerInnerLowerModuleIndex;
    trackletsInGPU.lowerModuleIndices[trackletIndex * 4 + 1] = innerOuterLowerModuleIndex;
    trackletsInGPU.lowerModuleIndices[trackletIndex * 4 + 2] = outerInnerLowerModuleIndex;
    trackletsInGPU.lowerModuleIndices[trackletIndex * 4 + 3] = outerOuterLowerModuleIndex;

    trackletsInGPU.zOut[trackletIndex] = zOut;
    trackletsInGPU.rtOut[trackletIndex] = rtOut;
    trackletsInGPU.deltaPhiPos[trackletIndex] = deltaPhiPos;
    trackletsInGPU.deltaPhi[trackletIndex] = deltaPhi;

    trackletsInGPU.betaIn[trackletIndex] = betaIn;
    trackletsInGPU.betaOut[trackletIndex] = betaOut;
    trackletsInGPU.pt_beta[trackletIndex] = pt_beta;

#ifdef CUT_VALUE_DEBUG
    trackletsInGPU.zLo[trackletIndex] = zLo;
    trackletsInGPU.zHi[trackletIndex] = zHi;
    trackletsInGPU.rtLo[trackletIndex] = rtLo;
    trackletsInGPU.rtHi[trackletIndex] = rtHi;
    trackletsInGPU.zLoPointed[trackletIndex] = zLoPointed;
    trackletsInGPU.zHiPointed[trackletIndex] = zHiPointed;
    trackletsInGPU.sdlCut[trackletIndex] = sdlCut;
    trackletsInGPU.betaInCut[trackletIndex] = betaInCut;
    trackletsInGPU.betaOutCut[trackletIndex] = betaOutCut;
    trackletsInGPU.deltaBetaCut[trackletIndex] = deltaBetaCut;
    trackletsInGPU.kZ[trackletIndex] = kZ;
#endif
}

SDL::tracklets::tracklets()
{
    segmentIndices = nullptr;
    lowerModuleIndices = nullptr;
    zOut = nullptr;
    rtOut = nullptr;

    deltaPhiPos = nullptr;
    deltaPhi = nullptr;
    betaIn = nullptr;
    betaOut = nullptr;
    pt_beta = nullptr;
#ifdef CUT_VALUE_DEBUG
    zLo = nullptr;
    zHi = nullptr;
    rtLo = nullptr;
    rtHi = nullptr;
    zLoPointed = nullptr;
    zHiPointed = nullptr;
    sdlCut = nullptr;
    betaInCut = nullptr;
    betaOutCut = nullptr;
    deltaBetaCut = nullptr;
    kZ = nullptr;
#endif
}

SDL::tracklets::~tracklets()
{
}

void SDL::tracklets::freeMemoryCache()
{
#ifdef Explicit_Tracklet
    int dev;
    cudaGetDevice(&dev);
    cms::cuda::free_device(dev,segmentIndices);
    cms::cuda::free_device(dev,lowerModuleIndices);
    cms::cuda::free_device(dev,zOut);
    cms::cuda::free_device(dev,betaIn);
    cms::cuda::free_device(dev,nTracklets);
#else
    cms::cuda::free_managed(segmentIndices);
    cms::cuda::free_managed(lowerModuleIndices);
    cms::cuda::free_managed(zOut);
    cms::cuda::free_managed(betaIn);
    cms::cuda::free_managed(nTracklets);
#endif
}
void SDL::tracklets::freeMemory()
{
    cudaFree(segmentIndices);
    cudaFree(lowerModuleIndices);
    cudaFree(nTracklets);
    cudaFree(zOut);
    cudaFree(betaIn);
#ifdef CUT_VALUE_DEBUG
    cudaFree(zLo);
    cudaFree(zHi);
    cudaFree(rtLo);
    cudaFree(rtHi);
    cudaFree(zLoPointed);
    cudaFree(zHiPointed);
    cudaFree(sdlCut);
    cudaFree(betaInCut);
    cudaFree(betaOutCut);
    cudaFree(deltaBetaCut);
    cudaFree(kZ);
#endif
}

//__device__ bool SDL::runTrackletDefaultAlgo(struct modules& modulesInGPU, struct hits& hitsInGPU, struct miniDoublets& mdsInGPU, struct segments& segmentsInGPU, unsigned int innerInnerLowerModuleIndex, unsigned int innerOuterLowerModuleIndex, unsigned int outerInnerLowerModuleIndex, unsigned int outerOuterLowerModuleIndex, unsigned int innerSegmentIndex, unsigned int outerSegmentIndex, float& zOut, float& rtOut, float& deltaPhiPos, float& deltaPhi, float& betaIn, float&
//        betaOut, float& pt_beta, float& zLo, float& zHi, float& rtLo, float& rtHi, float& zLoPointed, float& zHiPointed, float& sdlCut, float& betaInCut, float& betaOutCut, float& deltaBetaCut, float& kZ, unsigned int N_MAX_SEGMENTS_PER_MODULE)
//{
//
//    bool pass = false;
//
//    zLo = -999;
//    zHi = -999;
//    rtLo = -999;
//    rtHi = -999;
//    zLoPointed = -999;
//    zHiPointed = -999;
//    kZ = -999;
//    betaInCut = -999;
//
//    short innerInnerLowerModuleSubdet = modulesInGPU.subdets[innerInnerLowerModuleIndex];
//    short innerOuterLowerModuleSubdet = modulesInGPU.subdets[innerOuterLowerModuleIndex];
//    short outerInnerLowerModuleSubdet = modulesInGPU.subdets[outerInnerLowerModuleIndex];
//    short outerOuterLowerModuleSubdet = modulesInGPU.subdets[outerOuterLowerModuleIndex];
//
//
//
//    if(innerInnerLowerModuleSubdet == SDL::Barrel
//            and innerOuterLowerModuleSubdet == SDL::Barrel
//            and outerInnerLowerModuleSubdet == SDL::Barrel
//            and outerOuterLowerModuleSubdet == SDL::Barrel)
//    {
//        pass = runTrackletDefaultAlgoBBBB(modulesInGPU,hitsInGPU,mdsInGPU,segmentsInGPU,innerInnerLowerModuleIndex,innerOuterLowerModuleIndex,outerInnerLowerModuleIndex,outerOuterLowerModuleIndex,innerSegmentIndex,outerSegmentIndex,zOut,rtOut,deltaPhiPos,deltaPhi,betaIn,betaOut,pt_beta, zLo, zHi, zLoPointed, zHiPointed, sdlCut, betaInCut, betaOutCut, deltaBetaCut);
//    }
//
//    else if(innerInnerLowerModuleSubdet == SDL::Barrel
//            and innerOuterLowerModuleSubdet == SDL::Barrel
//            and outerInnerLowerModuleSubdet == SDL::Endcap
//            and outerOuterLowerModuleSubdet == SDL::Endcap)
//    {
//        pass = runTrackletDefaultAlgoBBEE(modulesInGPU,hitsInGPU,mdsInGPU,segmentsInGPU,innerInnerLowerModuleIndex,innerOuterLowerModuleIndex,outerInnerLowerModuleIndex,outerOuterLowerModuleIndex,innerSegmentIndex,outerSegmentIndex,zOut,rtOut,deltaPhiPos,deltaPhi,betaIn,betaOut,pt_beta, zLo, rtLo, rtHi, sdlCut, betaInCut, betaOutCut, deltaBetaCut, kZ);
//    }
//
//    else if(innerInnerLowerModuleSubdet == SDL::Barrel
//            and innerOuterLowerModuleSubdet == SDL::Barrel
//            and outerInnerLowerModuleSubdet == SDL::Barrel
//            and outerOuterLowerModuleSubdet == SDL::Endcap)
//    {
//        pass = runTrackletDefaultAlgoBBBB(modulesInGPU,hitsInGPU,mdsInGPU,segmentsInGPU,innerInnerLowerModuleIndex,innerOuterLowerModuleIndex,outerInnerLowerModuleIndex,outerOuterLowerModuleIndex,innerSegmentIndex,outerSegmentIndex,zOut,rtOut,deltaPhiPos,deltaPhi,betaIn,betaOut,pt_beta,zLo, zHi, zLoPointed, zHiPointed, sdlCut, betaInCut, betaOutCut, deltaBetaCut);
//
//    }
//
//    else if(innerInnerLowerModuleSubdet == SDL::Barrel
//            and innerOuterLowerModuleSubdet == SDL::Endcap
//            and outerInnerLowerModuleSubdet == SDL::Endcap
//            and outerOuterLowerModuleSubdet == SDL::Endcap)
//    {
//        pass = runTrackletDefaultAlgoBBEE(modulesInGPU,hitsInGPU,mdsInGPU,segmentsInGPU,innerInnerLowerModuleIndex,innerOuterLowerModuleIndex,outerInnerLowerModuleIndex,outerOuterLowerModuleIndex,innerSegmentIndex,outerSegmentIndex,zOut,rtOut,deltaPhiPos,deltaPhi,betaIn,betaOut,pt_beta, zLo, rtLo, rtHi, sdlCut, betaInCut, betaOutCut, deltaBetaCut, kZ);
//
//    }
//
//    else if(innerInnerLowerModuleSubdet == SDL::Endcap
//            and innerOuterLowerModuleSubdet == SDL::Endcap
//            and outerInnerLowerModuleSubdet == SDL::Endcap
//            and outerOuterLowerModuleSubdet == SDL::Endcap)
//    {
//        pass = runTrackletDefaultAlgoEEEE(modulesInGPU,hitsInGPU,mdsInGPU,segmentsInGPU,innerInnerLowerModuleIndex,innerOuterLowerModuleIndex,outerInnerLowerModuleIndex,outerOuterLowerModuleIndex,innerSegmentIndex,outerSegmentIndex,zOut,rtOut,deltaPhiPos,deltaPhi,betaIn,betaOut,pt_beta, zLo, rtLo, rtHi, sdlCut, betaInCut, betaOutCut, deltaBetaCut, kZ);
//    }
//    
//    return pass;
//}

__device__ bool SDL::runTrackletDefaultAlgoBBBB(struct modules& modulesInGPU, struct miniDoublets& mdsInGPU, struct segments& segmentsInGPU, unsigned int& innerInnerLowerModuleIndex, unsigned int& innerOuterLowerModuleIndex, unsigned int& outerInnerLowerModuleIndex, unsigned int& outerOuterLowerModuleIndex, unsigned int& innerSegmentIndex, unsigned int& outerSegmentIndex, unsigned int& firstMDIndex, unsigned int& secondMDIndex, unsigned int& thirdMDIndex,
        unsigned int& fourthMDIndex, float& zOut, float& rtOut, float& deltaPhiPos, float& dPhi, float& betaIn, float&
        betaOut, float& pt_beta, float& zLo, float& zHi, float& zLoPointed, float& zHiPointed, float& sdlCut, float& betaInCut, float& betaOutCut, float& deltaBetaCut)
{
    bool pass = true;

    bool isPS_InLo = (modulesInGPU.moduleType[innerInnerLowerModuleIndex] == SDL::PS);
    bool isPS_OutLo = (modulesInGPU.moduleType[outerInnerLowerModuleIndex] == SDL::PS);

    float rt_InLo = mdsInGPU.anchorRt[firstMDIndex];
    float rt_InOut = mdsInGPU.anchorRt[secondMDIndex];
    float rt_OutLo = mdsInGPU.anchorRt[thirdMDIndex];

    float z_InLo = mdsInGPU.anchorZ[firstMDIndex];
    float z_InOut = mdsInGPU.anchorZ[secondMDIndex];
    float z_OutLo = mdsInGPU.anchorZ[thirdMDIndex];
    
    float alpha1GeV_OutLo = asinf(fminf(rt_OutLo * k2Rinv1GeVf / ptCut, sinAlphaMax));

    float rtRatio_OutLoInLo = rt_OutLo / rt_InLo; // Outer segment beginning rt divided by inner segment beginning rt;
    float dzDrtScale = tanf(alpha1GeV_OutLo) / alpha1GeV_OutLo; // The track can bend in r-z plane slightly
    float zpitch_InLo = (isPS_InLo ? pixelPSZpitch : strip2SZpitch);
    float zpitch_OutLo = (isPS_OutLo ? pixelPSZpitch : strip2SZpitch);

    zHi = z_InLo + (z_InLo + deltaZLum) * (rtRatio_OutLoInLo - 1.f) * (z_InLo < 0.f ? 1.f : dzDrtScale) + (zpitch_InLo + zpitch_OutLo);
    zLo = z_InLo + (z_InLo - deltaZLum) * (rtRatio_OutLoInLo - 1.f) * (z_InLo > 0.f ? 1.f : dzDrtScale) - (zpitch_InLo + zpitch_OutLo); 


    //Cut 1 - z compatibility
    zOut = z_OutLo;
    rtOut = rt_OutLo;
    pass = pass & ((z_OutLo >= zLo) & (z_OutLo <= zHi));

    float drt_OutLo_InLo = (rt_OutLo - rt_InLo);
    float r3_InLo = sqrtf(z_InLo * z_InLo + rt_InLo * rt_InLo);
    float drt_InSeg = rt_InOut - rt_InLo;
    float dz_InSeg = z_InOut - z_InLo;
    float dr3_InSeg = sqrtf(rt_InOut * rt_InOut + z_InOut * z_InOut) -sqrtf(rt_InLo * rt_InLo + z_InLo * z_InLo);

    float coshEta = dr3_InSeg/drt_InSeg;
    float dzErr = (zpitch_InLo + zpitch_OutLo) * (zpitch_InLo + zpitch_OutLo) * 2.f;

    float sdlThetaMulsF = 0.015f * sqrtf(0.1f + 0.2f * (rt_OutLo - rt_InLo) / 50.f) * sqrtf(r3_InLo / rt_InLo);
    float sdlMuls = sdlThetaMulsF * 3.f / ptCut * 4.f; // will need a better guess than x4?
    dzErr += sdlMuls * sdlMuls * drt_OutLo_InLo * drt_OutLo_InLo / 3.f * coshEta * coshEta; //sloppy
    dzErr = sqrtf(dzErr);

    // Constructing upper and lower bound
    const float dzMean = dz_InSeg / drt_InSeg * drt_OutLo_InLo;
    const float zWindow = dzErr / drt_InSeg * drt_OutLo_InLo + (zpitch_InLo + zpitch_OutLo); //FIXME for ptCut lower than ~0.8 need to add curv path correction
    zLoPointed = z_InLo + dzMean * (z_InLo > 0.f ? 1.f : dzDrtScale) - zWindow;
    zHiPointed = z_InLo + dzMean * (z_InLo < 0.f ? 1.f : dzDrtScale) + zWindow;

    // Cut #2: Pointed Z (Inner segment two MD points to outer segment inner MD)
    pass = pass & ((z_OutLo >= zLoPointed) & (z_OutLo <= zHiPointed));
    float sdlPVoff = 0.1f/rt_OutLo;
    sdlCut = alpha1GeV_OutLo + sqrtf(sdlMuls * sdlMuls + sdlPVoff * sdlPVoff);
    
    deltaPhiPos = deltaPhi(mdsInGPU.anchorX[secondMDIndex], mdsInGPU.anchorY[secondMDIndex], mdsInGPU.anchorZ[secondMDIndex], mdsInGPU.anchorX[fourthMDIndex], mdsInGPU.anchorY[fourthMDIndex], mdsInGPU.anchorZ[fourthMDIndex]); 
    // Cut #3: FIXME:deltaPhiPos can be tighter
    pass = pass & (fabsf(deltaPhiPos) <= sdlCut);

    float midPointX = 0.5f*(mdsInGPU.anchorX[firstMDIndex] + mdsInGPU.anchorX[thirdMDIndex]);
    float midPointY = 0.5f* (mdsInGPU.anchorY[firstMDIndex] + mdsInGPU.anchorY[thirdMDIndex]);
    float midPointZ = 0.5f*(mdsInGPU.anchorZ[firstMDIndex] + mdsInGPU.anchorZ[thirdMDIndex]);
    float diffX = mdsInGPU.anchorX[thirdMDIndex] - mdsInGPU.anchorX[firstMDIndex];
    float diffY = mdsInGPU.anchorY[thirdMDIndex] - mdsInGPU.anchorY[firstMDIndex];
    float diffZ = mdsInGPU.anchorZ[thirdMDIndex] - mdsInGPU.anchorZ[firstMDIndex];

    dPhi = deltaPhi(midPointX, midPointY, midPointZ, diffX, diffY, diffZ);

    // Cut #4: deltaPhiChange
    pass = pass & (fabsf(dPhi) <= sdlCut);

    // First obtaining the raw betaIn and betaOut values without any correction and just purely based on the mini-doublet hit positions

    float alpha_InLo  = __H2F(segmentsInGPU.dPhiChanges[innerSegmentIndex]);
    float alpha_OutLo = __H2F(segmentsInGPU.dPhiChanges[outerSegmentIndex]);

    bool isEC_lastLayer = modulesInGPU.subdets[outerOuterLowerModuleIndex] == SDL::Endcap and modulesInGPU.moduleType[outerOuterLowerModuleIndex] == SDL::TwoS;

    float alpha_OutUp,alpha_OutUp_highEdge,alpha_OutUp_lowEdge;
   
    alpha_OutUp = deltaPhi(mdsInGPU.anchorX[fourthMDIndex], mdsInGPU.anchorY[fourthMDIndex], mdsInGPU.anchorZ[fourthMDIndex], mdsInGPU.anchorX[fourthMDIndex] - mdsInGPU.anchorX[thirdMDIndex], mdsInGPU.anchorY[fourthMDIndex] - mdsInGPU.anchorY[thirdMDIndex], mdsInGPU.anchorZ[fourthMDIndex] - mdsInGPU.anchorZ[thirdMDIndex]);

    alpha_OutUp_highEdge = alpha_OutUp;
    alpha_OutUp_lowEdge = alpha_OutUp;

    float tl_axis_x = mdsInGPU.anchorX[fourthMDIndex] - mdsInGPU.anchorX[firstMDIndex];
    float tl_axis_y = mdsInGPU.anchorY[fourthMDIndex] - mdsInGPU.anchorY[firstMDIndex];
    float tl_axis_z = mdsInGPU.anchorZ[fourthMDIndex] - mdsInGPU.anchorZ[firstMDIndex];
    float tl_axis_highEdge_x = tl_axis_x;
    float tl_axis_highEdge_y = tl_axis_y;
    float tl_axis_lowEdge_x = tl_axis_x;
    float tl_axis_lowEdge_y = tl_axis_y;

    betaIn = alpha_InLo - deltaPhi(mdsInGPU.anchorX[firstMDIndex], mdsInGPU.anchorY[firstMDIndex], mdsInGPU.anchorZ[firstMDIndex], tl_axis_x, tl_axis_y, tl_axis_z);

    float betaInRHmin = betaIn;
    float betaInRHmax = betaIn;
    betaOut = -alpha_OutUp + deltaPhi(mdsInGPU.anchorX[fourthMDIndex], mdsInGPU.anchorY[fourthMDIndex], mdsInGPU.anchorZ[fourthMDIndex], tl_axis_x, tl_axis_y, tl_axis_z);

    float betaOutRHmin = betaOut;
    float betaOutRHmax = betaOut;

    if(isEC_lastLayer)
    {
        alpha_OutUp_highEdge = deltaPhi(mdsInGPU.anchorHighEdgeX[fourthMDIndex], mdsInGPU.anchorHighEdgeY[fourthMDIndex], mdsInGPU.anchorZ[fourthMDIndex], mdsInGPU.anchorHighEdgeX[fourthMDIndex] - mdsInGPU.anchorX[thirdMDIndex], mdsInGPU.anchorHighEdgeY[fourthMDIndex] - mdsInGPU.anchorY[thirdMDIndex], mdsInGPU.anchorZ[fourthMDIndex] - mdsInGPU.anchorZ[thirdMDIndex]);
        alpha_OutUp_lowEdge = deltaPhi(mdsInGPU.anchorLowEdgeX[fourthMDIndex], mdsInGPU.anchorLowEdgeY[fourthMDIndex], mdsInGPU.anchorZ[fourthMDIndex], mdsInGPU.anchorLowEdgeX[fourthMDIndex] - mdsInGPU.anchorX[thirdMDIndex], mdsInGPU.anchorLowEdgeY[fourthMDIndex] - mdsInGPU.anchorY[thirdMDIndex], mdsInGPU.anchorZ[fourthMDIndex] - mdsInGPU.anchorZ[thirdMDIndex]);

        tl_axis_highEdge_x = mdsInGPU.anchorHighEdgeX[fourthMDIndex] - mdsInGPU.anchorX[firstMDIndex];
        tl_axis_highEdge_y = mdsInGPU.anchorHighEdgeY[fourthMDIndex] - mdsInGPU.anchorY[firstMDIndex];
        tl_axis_lowEdge_x = mdsInGPU.anchorLowEdgeX[fourthMDIndex] - mdsInGPU.anchorX[firstMDIndex];
        tl_axis_lowEdge_y = mdsInGPU.anchorLowEdgeY[fourthMDIndex] - mdsInGPU.anchorY[firstMDIndex];
   
  
        betaOutRHmin = -alpha_OutUp_highEdge + deltaPhi(mdsInGPU.anchorHighEdgeX[fourthMDIndex], mdsInGPU.anchorHighEdgeY[fourthMDIndex], mdsInGPU.anchorZ[fourthMDIndex], tl_axis_highEdge_x, tl_axis_highEdge_y, tl_axis_z);
        betaOutRHmax = -alpha_OutUp_lowEdge + deltaPhi(mdsInGPU.anchorLowEdgeX[fourthMDIndex], mdsInGPU.anchorLowEdgeY[fourthMDIndex], mdsInGPU.anchorZ[fourthMDIndex], tl_axis_lowEdge_x, tl_axis_lowEdge_y, tl_axis_z); 
    }

    //beta computation
    float drt_tl_axis = sqrtf(tl_axis_x * tl_axis_x + tl_axis_y * tl_axis_y);
    float drt_tl_lowEdge = sqrtf(tl_axis_lowEdge_x * tl_axis_lowEdge_x + tl_axis_lowEdge_y * tl_axis_lowEdge_y);
    float drt_tl_highEdge = sqrtf(tl_axis_highEdge_x * tl_axis_highEdge_x + tl_axis_highEdge_y * tl_axis_highEdge_y);

    float corrF = 1.f;
    bool pass_betaIn_cut = false;
    //innerOuterAnchor - innerInnerAnchor
    const float rt_InSeg = sqrtf((mdsInGPU.anchorX[secondMDIndex] - mdsInGPU.anchorX[firstMDIndex]) * (mdsInGPU.anchorX[secondMDIndex] - mdsInGPU.anchorX[firstMDIndex]) + (mdsInGPU.anchorY[secondMDIndex] - mdsInGPU.anchorY[firstMDIndex]) * (mdsInGPU.anchorY[secondMDIndex] - mdsInGPU.anchorY[firstMDIndex]));
    betaInCut = asinf(fminf((-rt_InSeg * corrF + drt_tl_axis) * k2Rinv1GeVf / ptCut, sinAlphaMax)) + (0.02f / drt_InSeg);

    //Cut #5: first beta cut
    pass = pass & (fabsf(betaInRHmin) < betaInCut);

    float betaAv = 0.5f * (betaIn + betaOut);
    pt_beta = drt_tl_axis * k2Rinv1GeVf/sinf(betaAv);
    int lIn = 5;
    int lOut = isEC_lastLayer ? 11 : 5;
    float sdOut_dr = sqrtf((mdsInGPU.anchorX[fourthMDIndex] - mdsInGPU.anchorX[thirdMDIndex]) * (mdsInGPU.anchorX[fourthMDIndex] - mdsInGPU.anchorX[thirdMDIndex]) + (mdsInGPU.anchorY[fourthMDIndex] - mdsInGPU.anchorY[thirdMDIndex]) * (mdsInGPU.anchorY[fourthMDIndex] - mdsInGPU.anchorY[thirdMDIndex]));
    float sdOut_d = mdsInGPU.anchorRt[fourthMDIndex] - mdsInGPU.anchorRt[thirdMDIndex];

    const float diffDr = fabsf(rt_InSeg - sdOut_dr) / fabsf(rt_InSeg + sdOut_dr);

    runDeltaBetaIterations(betaIn, betaOut, betaAv, pt_beta, rt_InSeg, sdOut_dr, drt_tl_axis, lIn);

    const float betaInMMSF = (fabsf(betaInRHmin + betaInRHmax) > 0) ? (2.f * betaIn / fabsf(betaInRHmin + betaInRHmax)) : 0.f; //mean value of min,max is the old betaIn
    const float betaOutMMSF = (fabsf(betaOutRHmin + betaOutRHmax) > 0) ? (2.f * betaOut / fabsf(betaOutRHmin + betaOutRHmax)) : 0.f;
    betaInRHmin *= betaInMMSF;
    betaInRHmax *= betaInMMSF;
    betaOutRHmin *= betaOutMMSF;
    betaOutRHmax *= betaOutMMSF;

    const float dBetaMuls = sdlThetaMulsF * 4.f / fminf(fabsf(pt_beta), pt_betaMax); //need to confirm the range-out value of 7 GeV


    const float alphaInAbsReg = fmaxf(fabsf(alpha_InLo), asinf(fminf(rt_InLo * k2Rinv1GeVf / 3.0f, sinAlphaMax)));
    const float alphaOutAbsReg = fmaxf(fabs(alpha_OutLo), asinf(fminf(rt_OutLo * k2Rinv1GeVf / 3.0f, sinAlphaMax)));
    const float dBetaInLum = lIn < 11 ? 0.0f : fabsf(alphaInAbsReg*deltaZLum / z_InLo);
    const float dBetaOutLum = lOut < 11 ? 0.0f : fabsf(alphaOutAbsReg*deltaZLum / z_OutLo);
    const float dBetaLum2 = (dBetaInLum + dBetaOutLum) * (dBetaInLum + dBetaOutLum);
    const float sinDPhi = sinf(dPhi);

    const float dBetaRIn2 = 0; // TODO-RH
    // const float dBetaROut2 = 0; // TODO-RH
    float dBetaROut = 0;
    if(isEC_lastLayer)
    {
        dBetaROut = (sqrtf(mdsInGPU.anchorHighEdgeX[fourthMDIndex] * mdsInGPU.anchorHighEdgeX[fourthMDIndex] + mdsInGPU.anchorHighEdgeY[fourthMDIndex] * mdsInGPU.anchorHighEdgeY[fourthMDIndex]) - sqrtf(mdsInGPU.anchorLowEdgeX[fourthMDIndex] * mdsInGPU.anchorLowEdgeX[fourthMDIndex] + mdsInGPU.anchorLowEdgeY[fourthMDIndex] * mdsInGPU.anchorLowEdgeY[fourthMDIndex])) * sinDPhi / drt_tl_axis;
    }

    const float dBetaROut2 =  dBetaROut * dBetaROut;

    betaOutCut = asinf(fminf(drt_tl_axis*k2Rinv1GeVf / ptCut, sinAlphaMax)) //FIXME: need faster version
        + (0.02f / sdOut_d) + sqrtf(dBetaLum2 + dBetaMuls*dBetaMuls);

    //Cut #6: The real beta cut
    pass = pass & ((fabsf(betaOut) < betaOutCut));
    
    float pt_betaIn = drt_tl_axis * k2Rinv1GeVf/sinf(betaIn);
    float pt_betaOut = drt_tl_axis * k2Rinv1GeVf / sinf(betaOut);
    float dBetaRes = 0.02f/fminf(sdOut_d,drt_InSeg);
    float dBetaCut2 = (dBetaRes*dBetaRes * 2.0f + dBetaMuls * dBetaMuls + dBetaLum2 + dBetaRIn2 + dBetaROut2
            + 0.25f * (fabsf(betaInRHmin - betaInRHmax) + fabsf(betaOutRHmin - betaOutRHmax)) * (fabsf(betaInRHmin - betaInRHmax) + fabsf(betaOutRHmin - betaOutRHmax)));

    float dBeta = betaIn - betaOut;
    deltaBetaCut = sqrtf(dBetaCut2);   
    pass = pass & (dBeta * dBeta <= dBetaCut2);

    return pass;
}

__device__ bool SDL::runTrackletDefaultAlgoBBEE(struct modules& modulesInGPU, struct miniDoublets& mdsInGPU, struct segments& segmentsInGPU, unsigned int& innerInnerLowerModuleIndex, unsigned int& innerOuterLowerModuleIndex, unsigned int& outerInnerLowerModuleIndex, unsigned int& outerOuterLowerModuleIndex, unsigned int& innerSegmentIndex, unsigned int& outerSegmentIndex, unsigned int& firstMDIndex, unsigned int& secondMDIndex, unsigned int& thirdMDIndex,
        unsigned int& fourthMDIndex, float& zOut, float& rtOut, float& deltaPhiPos, float& dPhi, float& betaIn, float&
        betaOut, float& pt_beta, float& zLo, float& rtLo, float& rtHi, float& sdlCut, float& betaInCut, float& betaOutCut, float& deltaBetaCut, float& kZ)
{
    bool pass = true;
    bool isPS_InLo = (modulesInGPU.moduleType[innerInnerLowerModuleIndex] == SDL::PS);
    bool isPS_OutLo = (modulesInGPU.moduleType[outerInnerLowerModuleIndex] == SDL::PS);

    float rt_InLo = mdsInGPU.anchorRt[firstMDIndex];
    float rt_InOut = mdsInGPU.anchorRt[secondMDIndex];
    float rt_OutLo = mdsInGPU.anchorRt[thirdMDIndex];

    float z_InLo = mdsInGPU.anchorZ[firstMDIndex];
    float z_InOut = mdsInGPU.anchorZ[secondMDIndex];
    float z_OutLo = mdsInGPU.anchorZ[thirdMDIndex];

    float alpha1GeV_OutLo = asinf(fminf(rt_OutLo * k2Rinv1GeVf / ptCut, sinAlphaMax));

    float rtRatio_OutLoInLo = rt_OutLo / rt_InLo; // Outer segment beginning rt divided by inner segment beginning rt;
    float dzDrtScale = tanf(alpha1GeV_OutLo) / alpha1GeV_OutLo; // The track can bend in r-z plane slightly
    float zpitch_InLo = (isPS_InLo ? pixelPSZpitch : strip2SZpitch);
    float zpitch_OutLo = (isPS_OutLo ? pixelPSZpitch : strip2SZpitch);
    float zGeom = zpitch_InLo + zpitch_OutLo;

    zLo = z_InLo + (z_InLo - deltaZLum) * (rtRatio_OutLoInLo - 1.f) * (z_InLo > 0.f ? 1.f : dzDrtScale) - zGeom; 

    // Cut #0: Preliminary (Only here in endcap case)
    pass = pass & (z_InLo * z_OutLo > 0);

    float dLum = copysignf(deltaZLum, z_InLo);
    bool isOutSgInnerMDPS = modulesInGPU.moduleType[outerInnerLowerModuleIndex] == SDL::PS;
    float rtGeom1 = isOutSgInnerMDPS ? pixelPSZpitch : strip2SZpitch;
    float zGeom1 = copysignf(zGeom,z_InLo);
    rtLo = rt_InLo * (1.f + (z_OutLo - z_InLo - zGeom1) / (z_InLo + zGeom1 + dLum) / dzDrtScale) - rtGeom1; //slope correction only on the lower end
    zOut = z_OutLo;
    rtOut = rt_OutLo;

    //Cut #1: rt condition
    pass = pass & (rtOut >= rtLo);

    float zInForHi = z_InLo - zGeom1 - dLum;
    if(zInForHi * z_InLo < 0)
    {
        zInForHi = copysignf(0.1f,z_InLo);
    }
    rtHi = rt_InLo * (1.f + (z_OutLo - z_InLo + zGeom1) / zInForHi) + rtGeom1;

    //Cut #2: rt condition
    pass = pass & ((rt_OutLo >= rtLo) & (rt_OutLo <= rtHi));

    float rIn = sqrtf(z_InLo * z_InLo + rt_InLo * rt_InLo);
    const float drtSDIn = rt_InOut - rt_InLo;
    const float dzSDIn = z_InOut - z_InLo;
    const float dr3SDIn = sqrtf(rt_InOut * rt_InOut + z_InOut * z_InOut) - sqrtf(rt_InLo * rt_InLo + z_InLo * z_InLo);

    const float coshEta = dr3SDIn / drtSDIn; //direction estimate
    const float dzOutInAbs = fabsf(z_OutLo - z_InLo);
    const float multDzDr = dzOutInAbs * coshEta / (coshEta * coshEta - 1.f);
    const float zGeom1_another = pixelPSZpitch; //What's this?
    kZ = (z_OutLo - z_InLo) / dzSDIn;
    float drtErr = zGeom1_another * zGeom1_another * drtSDIn * drtSDIn / dzSDIn / dzSDIn * (1.f - 2.f * kZ + 2.f * kZ * kZ); //Notes:122316
    const float sdlThetaMulsF = 0.015f * sqrtf(0.1f + 0.2f * (rt_OutLo - rt_InLo) / 50.f) * sqrtf(rIn / rt_InLo);
    const float sdlMuls = sdlThetaMulsF * 3.f / ptCut * 4.f; //will need a better guess than x4?
    drtErr += sdlMuls * sdlMuls * multDzDr * multDzDr / 3.f * coshEta * coshEta; //sloppy: relative muls is 1/3 of total muls
    drtErr = sqrtf(drtErr);
    const float drtMean = drtSDIn * dzOutInAbs / fabsf(dzSDIn); //
    const float rtWindow = drtErr + rtGeom1;
    const float rtLo_another = rt_InLo + drtMean / dzDrtScale - rtWindow;
    const float rtHi_another = rt_InLo + drtMean + rtWindow;

    //Cut #3: rt-z pointed
    pass = pass & ((kZ >= 0) & (rtOut >= rtLo) & (rtOut <= rtHi));
    const float sdlPVoff = 0.1f / rt_OutLo;
    sdlCut = alpha1GeV_OutLo + sqrtf(sdlMuls * sdlMuls + sdlPVoff*sdlPVoff);


    deltaPhiPos = deltaPhi(mdsInGPU.anchorX[secondMDIndex], mdsInGPU.anchorY[secondMDIndex], mdsInGPU.anchorZ[secondMDIndex], mdsInGPU.anchorX[fourthMDIndex], mdsInGPU.anchorY[fourthMDIndex], mdsInGPU.anchorZ[fourthMDIndex]); 


    //Cut #4: deltaPhiPos can be tighter
    pass = pass & (fabsf(deltaPhiPos) <= sdlCut);

    float midPointX = 0.5f*(mdsInGPU.anchorX[firstMDIndex] + mdsInGPU.anchorX[thirdMDIndex]);
    float midPointY = 0.5f* (mdsInGPU.anchorY[firstMDIndex] + mdsInGPU.anchorY[thirdMDIndex]);
    float midPointZ = 0.5f*(mdsInGPU.anchorZ[firstMDIndex] + mdsInGPU.anchorZ[thirdMDIndex]);
    float diffX = mdsInGPU.anchorX[thirdMDIndex] - mdsInGPU.anchorX[firstMDIndex];
    float diffY = mdsInGPU.anchorY[thirdMDIndex] - mdsInGPU.anchorY[firstMDIndex];
    float diffZ = mdsInGPU.anchorZ[thirdMDIndex] - mdsInGPU.anchorZ[firstMDIndex];

    dPhi = deltaPhi(midPointX, midPointY, midPointZ, diffX, diffY, diffZ);
    // Cut #5: deltaPhiChange
    pass = pass & (fabsf(dPhi) <= sdlCut);
    
    float sdIn_alpha     = __H2F(segmentsInGPU.dPhiChanges[innerSegmentIndex]);
    float sdIn_alpha_min = __H2F(segmentsInGPU.dPhiChangeMins[innerSegmentIndex]);
    float sdIn_alpha_max = __H2F(segmentsInGPU.dPhiChangeMaxs[innerSegmentIndex]);
    float sdOut_alpha = sdIn_alpha; //weird

    float sdOut_alphaOut = deltaPhi(mdsInGPU.anchorX[fourthMDIndex], mdsInGPU.anchorY[fourthMDIndex], mdsInGPU.anchorZ[fourthMDIndex], mdsInGPU.anchorX[fourthMDIndex] - mdsInGPU.anchorX[thirdMDIndex], mdsInGPU.anchorY[fourthMDIndex] - mdsInGPU.anchorY[thirdMDIndex], mdsInGPU.anchorZ[fourthMDIndex] - mdsInGPU.anchorZ[thirdMDIndex]);

    float sdOut_alphaOut_min = phi_mpi_pi(__H2F(segmentsInGPU.dPhiChangeMins[outerSegmentIndex]) - __H2F(segmentsInGPU.dPhiMins[outerSegmentIndex]));
    float sdOut_alphaOut_max = phi_mpi_pi(__H2F(segmentsInGPU.dPhiChangeMaxs[outerSegmentIndex]) - __H2F(segmentsInGPU.dPhiMaxs[outerSegmentIndex]));

    float tl_axis_x = mdsInGPU.anchorX[fourthMDIndex] - mdsInGPU.anchorX[firstMDIndex];
    float tl_axis_y = mdsInGPU.anchorY[fourthMDIndex] - mdsInGPU.anchorY[firstMDIndex];
    float tl_axis_z = mdsInGPU.anchorZ[fourthMDIndex] - mdsInGPU.anchorZ[firstMDIndex];

    betaIn = sdIn_alpha - deltaPhi(mdsInGPU.anchorX[firstMDIndex], mdsInGPU.anchorY[firstMDIndex], mdsInGPU.anchorZ[firstMDIndex], tl_axis_x, tl_axis_y, tl_axis_z);

    float betaInRHmin = betaIn;
    float betaInRHmax = betaIn;
    betaOut = -sdOut_alphaOut + deltaPhi(mdsInGPU.anchorX[fourthMDIndex], mdsInGPU.anchorY[fourthMDIndex], mdsInGPU.anchorZ[fourthMDIndex], tl_axis_x, tl_axis_y, tl_axis_z);

    float betaOutRHmin = betaOut;
    float betaOutRHmax = betaOut;

    bool isEC_secondLayer = (modulesInGPU.subdets[innerOuterLowerModuleIndex] == SDL::Endcap) and (modulesInGPU.moduleType[innerOuterLowerModuleIndex] == SDL::TwoS);

    if(isEC_secondLayer)
    {
        betaInRHmin = betaIn - sdIn_alpha_min + sdIn_alpha;
        betaInRHmax = betaIn - sdIn_alpha_max + sdIn_alpha;
    }

    betaOutRHmin = betaOut - sdOut_alphaOut_min + sdOut_alphaOut;
    betaOutRHmax = betaOut - sdOut_alphaOut_max + sdOut_alphaOut;
    
    float swapTemp;
    if(fabsf(betaOutRHmin) > fabsf(betaOutRHmax))
    {
        swapTemp = betaOutRHmin;
        betaOutRHmin = betaOutRHmax;
        betaOutRHmax = swapTemp;
    }

    if(fabsf(betaInRHmin) > fabsf(betaInRHmax))
    {
        swapTemp = betaInRHmin;
        betaInRHmin = betaInRHmax;
        betaInRHmax = swapTemp;
    }
   
    float sdIn_dr = sqrtf((mdsInGPU.anchorX[secondMDIndex] - mdsInGPU.anchorX[firstMDIndex]) * (mdsInGPU.anchorX[secondMDIndex] - mdsInGPU.anchorX[firstMDIndex]) + (mdsInGPU.anchorY[secondMDIndex] - mdsInGPU.anchorY[firstMDIndex]) * (mdsInGPU.anchorY[secondMDIndex] - mdsInGPU.anchorY[firstMDIndex]));
    float sdIn_d = rt_InOut - rt_InLo;

    float dr = sqrtf(tl_axis_x * tl_axis_x + tl_axis_y * tl_axis_y);
    const float corrF = 1.f;
    betaInCut = asinf(fminf((-sdIn_dr * corrF + dr) * k2Rinv1GeVf / ptCut, sinAlphaMax)) + (0.02f / sdIn_d);

    //Cut #6: first beta cut
    pass = pass & (fabsf(betaInRHmin) < betaInCut);

    float betaAv = 0.5f * (betaIn + betaOut);
    pt_beta = dr * k2Rinv1GeVf / sinf(betaAv);

    float lIn = 5;
    float lOut = 11;

    float sdOut_dr = sqrtf((mdsInGPU.anchorX[fourthMDIndex] - mdsInGPU.anchorX[thirdMDIndex]) * (mdsInGPU.anchorX[fourthMDIndex] - mdsInGPU.anchorX[thirdMDIndex]) + (mdsInGPU.anchorY[fourthMDIndex] - mdsInGPU.anchorY[thirdMDIndex]) * (mdsInGPU.anchorY[fourthMDIndex] - mdsInGPU.anchorY[thirdMDIndex]));
    float sdOut_d = mdsInGPU.anchorRt[fourthMDIndex] - mdsInGPU.anchorRt[thirdMDIndex];
     
    runDeltaBetaIterations(betaIn, betaOut, betaAv, pt_beta, sdIn_dr, sdOut_dr, dr, lIn);

     const float betaInMMSF = (fabsf(betaInRHmin + betaInRHmax) > 0) ? (2.f * betaIn / fabsf(betaInRHmin + betaInRHmax)) : 0.; //mean value of min,max is the old betaIn
    const float betaOutMMSF = (fabsf(betaOutRHmin + betaOutRHmax) > 0) ? (2.f * betaOut / fabsf(betaOutRHmin + betaOutRHmax)) : 0.;
    betaInRHmin *= betaInMMSF;
    betaInRHmax *= betaInMMSF;
    betaOutRHmin *= betaOutMMSF;
    betaOutRHmax *= betaOutMMSF;

    const float dBetaMuls = sdlThetaMulsF * 4.f / fminf(fabsf(pt_beta), pt_betaMax); //need to confirm the range-out value of 7 GeV

    const float alphaInAbsReg = fmaxf(fabsf(sdIn_alpha), asinf(fminf(rt_InLo * k2Rinv1GeVf / 3.0f, sinAlphaMax)));
    const float alphaOutAbsReg = fmaxf(fabsf(sdOut_alpha), asinf(fminf(rt_OutLo * k2Rinv1GeVf / 3.0f, sinAlphaMax)));
    const float dBetaInLum = lIn < 11 ? 0.0f : fabsf(alphaInAbsReg*deltaZLum / z_InLo);
    const float dBetaOutLum = lOut < 11 ? 0.0f : fabsf(alphaOutAbsReg*deltaZLum / z_OutLo);
    const float dBetaLum2 = (dBetaInLum + dBetaOutLum) * (dBetaInLum + dBetaOutLum);
    const float sinDPhi = sinf(dPhi);

    const float dBetaRIn2 = 0; // TODO-RH
    // const float dBetaROut2 = 0; // TODO-RH
    float dBetaROut = 0;
    if(modulesInGPU.moduleType[outerOuterLowerModuleIndex] == SDL::TwoS)
    {

        dBetaROut = (sqrtf(mdsInGPU.anchorHighEdgeX[fourthMDIndex] * mdsInGPU.anchorHighEdgeX[fourthMDIndex] + mdsInGPU.anchorHighEdgeY[fourthMDIndex] * mdsInGPU.anchorHighEdgeY[fourthMDIndex]) - sqrtf(mdsInGPU.anchorLowEdgeX[fourthMDIndex] * mdsInGPU.anchorLowEdgeX[fourthMDIndex] + mdsInGPU.anchorLowEdgeY[fourthMDIndex] * mdsInGPU.anchorLowEdgeY[fourthMDIndex])) * sinDPhi / dr; 

    }

    const float dBetaROut2 = dBetaROut * dBetaROut;
    betaOutCut = asinf(fminf(dr*k2Rinv1GeVf / ptCut, sinAlphaMax)) //FIXME: need faster version
        + (0.02f / sdOut_d) + sqrtf(dBetaLum2 + dBetaMuls*dBetaMuls);

    //Cut #6: The real beta cut
    pass = pass & (fabsf(betaOut) < betaOutCut);

    float pt_betaIn = dr * k2Rinv1GeVf/sinf(betaIn);
    float pt_betaOut = dr * k2Rinv1GeVf / sinf(betaOut);
    float dBetaRes = 0.02f/fminf(sdOut_d,sdIn_d);
    float dBetaCut2 = (dBetaRes*dBetaRes * 2.0f + dBetaMuls * dBetaMuls + dBetaLum2 + dBetaRIn2 + dBetaROut2
            + 0.25f * (fabsf(betaInRHmin - betaInRHmax) + fabsf(betaOutRHmin - betaOutRHmax)) * (fabsf(betaInRHmin - betaInRHmax) + fabsf(betaOutRHmin - betaOutRHmax)));
    float dBeta = betaIn - betaOut;
    deltaBetaCut = sqrtf(dBetaCut2);
    //Cut #7: Cut on dBet
    pass = pass & (dBeta * dBeta <= dBetaCut2);

    return pass;
}

__device__ bool SDL::runTrackletDefaultAlgoEEEE(struct modules& modulesInGPU, struct miniDoublets& mdsInGPU, struct segments& segmentsInGPU, unsigned int& innerInnerLowerModuleIndex, unsigned int& innerOuterLowerModuleIndex, unsigned int& outerInnerLowerModuleIndex, unsigned int& outerOuterLowerModuleIndex, unsigned int& innerSegmentIndex, unsigned int& outerSegmentIndex, unsigned int& firstMDIndex, unsigned int& secondMDIndex, unsigned int& thirdMDIndex,
        unsigned int& fourthMDIndex, float& zOut, float& rtOut, float& deltaPhiPos, float& dPhi, float& betaIn, float&
        betaOut, float& pt_beta, float& zLo, float& rtLo, float& rtHi, float& sdlCut, float& betaInCut, float& betaOutCut, float& deltaBetaCut, float& kZ)
{
    bool pass = true;
    
    bool isPS_InLo = (modulesInGPU.moduleType[innerInnerLowerModuleIndex] == SDL::PS);
    bool isPS_OutLo = (modulesInGPU.moduleType[outerInnerLowerModuleIndex] == SDL::PS);

    float rt_InLo = mdsInGPU.anchorRt[firstMDIndex];
    float rt_InOut = mdsInGPU.anchorRt[secondMDIndex];
    float rt_OutLo = mdsInGPU.anchorRt[thirdMDIndex];

    float z_InLo = mdsInGPU.anchorZ[firstMDIndex];
    float z_InOut = mdsInGPU.anchorZ[secondMDIndex];
    float z_OutLo = mdsInGPU.anchorZ[thirdMDIndex];
    
    float alpha1GeV_OutLo = asinf(fminf(rt_OutLo * k2Rinv1GeVf / ptCut, sinAlphaMax));

    float rtRatio_OutLoInLo = rt_OutLo / rt_InLo; // Outer segment beginning rt divided by inner segment beginning rt;
    float dzDrtScale = tanf(alpha1GeV_OutLo) / alpha1GeV_OutLo; // The track can bend in r-z plane slightly
    float zpitch_InLo = (isPS_InLo ? pixelPSZpitch : strip2SZpitch);
    float zpitch_OutLo = (isPS_OutLo ? pixelPSZpitch : strip2SZpitch);
    float zGeom = zpitch_InLo + zpitch_OutLo;

    zLo = z_InLo + (z_InLo - deltaZLum) * (rtRatio_OutLoInLo - 1.f) * (z_InLo > 0.f ? 1.f : dzDrtScale) - zGeom; //slope-correction only on outer end

    // Cut #0: Preliminary (Only here in endcap case)
    pass = pass & ((z_InLo * z_OutLo) > 0);
    
    float dLum = copysignf(deltaZLum, z_InLo);
    bool isOutSgInnerMDPS = modulesInGPU.moduleType[outerInnerLowerModuleIndex] == SDL::PS;
    bool isInSgInnerMDPS = modulesInGPU.moduleType[innerInnerLowerModuleIndex] == SDL::PS;

    float rtGeom = (isInSgInnerMDPS and isOutSgInnerMDPS) ? 2.f * pixelPSZpitch : (isInSgInnerMDPS or isOutSgInnerMDPS) ? pixelPSZpitch + strip2SZpitch : 2.f * strip2SZpitch;

    float zGeom1 = copysignf(zGeom,z_InLo);
    float dz = z_OutLo - z_InLo;
    rtLo = rt_InLo * (1.f + dz / (z_InLo + dLum) / dzDrtScale) - rtGeom; //slope correction only on the lower end

    zOut = z_OutLo;
    rtOut = rt_OutLo;

    //Cut #1: rt condition

    rtHi = rt_InLo * (1.f + dz / (z_InLo - dLum)) + rtGeom;

    pass = pass & ((rtOut >= rtLo) & (rtOut <= rtHi));

    bool isInSgOuterMDPS = modulesInGPU.moduleType[innerOuterLowerModuleIndex] == SDL::PS;

    float drOutIn = rtOut - rt_InLo;
    const float drtSDIn = rt_InOut - rt_InLo;
    const float dzSDIn = z_InOut - z_InLo;
    const float dr3SDIn = sqrtf(rt_InOut * rt_InOut + z_InOut * z_InOut) - sqrtf(rt_InLo * rt_InLo + z_InLo * z_InLo);
    float coshEta = dr3SDIn / drtSDIn; //direction estimate
    float dzOutInAbs =  fabsf(z_OutLo - z_InLo);
    float multDzDr = dzOutInAbs * coshEta / (coshEta * coshEta - 1.f);

    kZ = (z_OutLo - z_InLo) / dzSDIn;
    float sdlThetaMulsF = 0.015f * sqrtf(0.1f + 0.2f * (rt_OutLo - rt_InLo) / 50.f);

    float sdlMuls = sdlThetaMulsF * 3.f / ptCut * 4.f; //will need a better guess than x4?

    float drtErr = sqrtf(pixelPSZpitch * pixelPSZpitch * 2.f / (dzSDIn * dzSDIn) * (dzOutInAbs * dzOutInAbs) + sdlMuls * sdlMuls * multDzDr * multDzDr / 3.f * coshEta * coshEta);

    float drtMean = drtSDIn * dzOutInAbs/fabsf(dzSDIn);
    float rtWindow = drtErr + rtGeom;
    float rtLo_point = rt_InLo + drtMean / dzDrtScale - rtWindow;
    float rtHi_point = rt_InLo + drtMean + rtWindow;

    // Cut #3: rt-z pointed
    // https://github.com/slava77/cms-tkph2-ntuple/blob/superDoubletLinked-91X-noMock/doubletAnalysis.C#L3765

    if (isInSgInnerMDPS and isInSgOuterMDPS) // If both PS then we can point
    {
        pass = pass & (kZ >= 0 and rtOut >= rtLo_point and rtOut <= rtHi_point);
    }

    float sdlPVoff = 0.1f/rtOut;
    sdlCut = alpha1GeV_OutLo + sqrtf(sdlMuls * sdlMuls + sdlPVoff * sdlPVoff);

    deltaPhiPos = deltaPhi(mdsInGPU.anchorX[secondMDIndex], mdsInGPU.anchorY[secondMDIndex], mdsInGPU.anchorZ[secondMDIndex], mdsInGPU.anchorX[fourthMDIndex], mdsInGPU.anchorY[fourthMDIndex], mdsInGPU.anchorZ[fourthMDIndex]); 

    pass = pass & (fabsf(deltaPhiPos) <= sdlCut);

    float midPointX = 0.5f*(mdsInGPU.anchorX[firstMDIndex] + mdsInGPU.anchorX[thirdMDIndex]);
    float midPointY = 0.5f* (mdsInGPU.anchorY[firstMDIndex] + mdsInGPU.anchorY[thirdMDIndex]);
    float midPointZ = 0.5f*(mdsInGPU.anchorZ[firstMDIndex] + mdsInGPU.anchorZ[thirdMDIndex]);
    float diffX = mdsInGPU.anchorX[thirdMDIndex] - mdsInGPU.anchorX[firstMDIndex];
    float diffY = mdsInGPU.anchorY[thirdMDIndex] - mdsInGPU.anchorY[firstMDIndex];
    float diffZ = mdsInGPU.anchorZ[thirdMDIndex] - mdsInGPU.anchorZ[firstMDIndex];
   
    dPhi = deltaPhi(midPointX, midPointY, midPointZ, diffX, diffY, diffZ);

    // Cut #5: deltaPhiChange
    pass = pass & ((fabsf(dPhi) <= sdlCut));

    float sdIn_alpha = __H2F(segmentsInGPU.dPhiChanges[innerSegmentIndex]);
    float sdOut_alpha = sdIn_alpha; //weird
    float sdOut_dPhiPos = deltaPhi(mdsInGPU.anchorX[thirdMDIndex], mdsInGPU.anchorY[thirdMDIndex], mdsInGPU.anchorZ[thirdMDIndex], mdsInGPU.anchorX[fourthMDIndex], mdsInGPU.anchorY[fourthMDIndex], mdsInGPU.anchorZ[fourthMDIndex]);

    float sdOut_dPhiChange = __H2F(segmentsInGPU.dPhiChanges[outerSegmentIndex]);
    float sdOut_dPhiChange_min = __H2F(segmentsInGPU.dPhiChangeMins[outerSegmentIndex]);
    float sdOut_dPhiChange_max = __H2F(segmentsInGPU.dPhiChangeMaxs[outerSegmentIndex]);

    float sdOut_alphaOutRHmin = phi_mpi_pi(sdOut_dPhiChange_min - sdOut_dPhiPos);
    float sdOut_alphaOutRHmax = phi_mpi_pi(sdOut_dPhiChange_max - sdOut_dPhiPos);
    float sdOut_alphaOut = phi_mpi_pi(sdOut_dPhiChange - sdOut_dPhiPos);

    float tl_axis_x = mdsInGPU.anchorX[fourthMDIndex] - mdsInGPU.anchorX[firstMDIndex];
    float tl_axis_y = mdsInGPU.anchorY[fourthMDIndex] - mdsInGPU.anchorY[firstMDIndex];
    float tl_axis_z = mdsInGPU.anchorZ[fourthMDIndex] - mdsInGPU.anchorZ[firstMDIndex];
    
    betaIn = sdIn_alpha - deltaPhi(mdsInGPU.anchorX[firstMDIndex], mdsInGPU.anchorY[firstMDIndex], mdsInGPU.anchorZ[firstMDIndex], tl_axis_x, tl_axis_y, tl_axis_z);

    float sdIn_alphaRHmin = __H2F(segmentsInGPU.dPhiChangeMins[innerSegmentIndex]);
    float sdIn_alphaRHmax = __H2F(segmentsInGPU.dPhiChangeMaxs[innerSegmentIndex]);
    float betaInRHmin = betaIn + sdIn_alphaRHmin - sdIn_alpha;
    float betaInRHmax = betaIn + sdIn_alphaRHmax - sdIn_alpha;

    betaOut = -sdOut_alphaOut + deltaPhi(mdsInGPU.anchorX[fourthMDIndex], mdsInGPU.anchorY[fourthMDIndex], mdsInGPU.anchorZ[fourthMDIndex], tl_axis_x, tl_axis_y, tl_axis_z);

    float betaOutRHmin = betaOut - sdOut_alphaOutRHmin + sdOut_alphaOut;
    float betaOutRHmax = betaOut - sdOut_alphaOutRHmax + sdOut_alphaOut;
    
    float swapTemp;
    if(fabsf(betaOutRHmin) > fabsf(betaOutRHmax))
    {
        swapTemp = betaOutRHmin;
        betaOutRHmin = betaOutRHmax;
        betaOutRHmax = swapTemp;
    }

    if(fabsf(betaInRHmin) > fabsf(betaInRHmax))
    {
        swapTemp = betaInRHmin;
        betaInRHmin = betaInRHmax;
        betaInRHmax = swapTemp;
    }
    float sdIn_dr = sqrtf((mdsInGPU.anchorX[secondMDIndex] - mdsInGPU.anchorX[firstMDIndex]) * (mdsInGPU.anchorX[secondMDIndex] - mdsInGPU.anchorX[firstMDIndex]) + (mdsInGPU.anchorY[secondMDIndex] - mdsInGPU.anchorY[firstMDIndex]) * (mdsInGPU.anchorY[secondMDIndex] - mdsInGPU.anchorY[firstMDIndex]));
    float sdIn_d = rt_InOut - rt_InLo;

    float dr = sqrtf(tl_axis_x * tl_axis_x + tl_axis_y * tl_axis_y);
    const float corrF = 1.f;
    betaInCut = asinf(fminf((-sdIn_dr * corrF + dr) * k2Rinv1GeVf / ptCut, sinAlphaMax)) + (0.02f / sdIn_d);

    //Cut #6: first beta cut
    pass = pass & (fabsf(betaInRHmin) < betaInCut);
    float betaAv = 0.5f * (betaIn + betaOut);
    pt_beta = dr * k2Rinv1GeVf / sinf(betaAv);


    int lIn= 11; //endcap
    int lOut = 13; //endcap

    float sdOut_dr = sqrtf((mdsInGPU.anchorX[fourthMDIndex] - mdsInGPU.anchorX[thirdMDIndex]) * (mdsInGPU.anchorX[fourthMDIndex] - mdsInGPU.anchorX[thirdMDIndex]) + (mdsInGPU.anchorY[fourthMDIndex] - mdsInGPU.anchorY[thirdMDIndex]) * (mdsInGPU.anchorY[fourthMDIndex] - mdsInGPU.anchorY[thirdMDIndex]));
    float sdOut_d = mdsInGPU.anchorRt[fourthMDIndex] - mdsInGPU.anchorRt[thirdMDIndex];

    float diffDr = fabsf(sdIn_dr - sdOut_dr)/fabs(sdIn_dr + sdOut_dr);
    
    runDeltaBetaIterations(betaIn, betaOut, betaAv, pt_beta, sdIn_dr, sdOut_dr, dr, lIn);

     const float betaInMMSF = (fabsf(betaInRHmin + betaInRHmax) > 0) ? (2.f * betaIn / fabsf(betaInRHmin + betaInRHmax)) : 0.; //mean value of min,max is the old betaIn
    const float betaOutMMSF = (fabsf(betaOutRHmin + betaOutRHmax) > 0) ? (2.f * betaOut / fabsf(betaOutRHmin + betaOutRHmax)) : 0.;
    betaInRHmin *= betaInMMSF;
    betaInRHmax *= betaInMMSF;
    betaOutRHmin *= betaOutMMSF;
    betaOutRHmax *= betaOutMMSF;

    const float dBetaMuls = sdlThetaMulsF * 4.f / fminf(fabsf(pt_beta), pt_betaMax); //need to confirm the range-out value of 7 GeV

    const float alphaInAbsReg = fmaxf(fabsf(sdIn_alpha), asinf(fminf(rt_InLo * k2Rinv1GeVf / 3.0f, sinAlphaMax)));
    const float alphaOutAbsReg = fmaxf(fabsf(sdOut_alpha), asinf(fminf(rt_OutLo * k2Rinv1GeVf / 3.0f, sinAlphaMax)));
    const float dBetaInLum = lIn < 11 ? 0.0f : fabsf(alphaInAbsReg*deltaZLum / z_InLo);
    const float dBetaOutLum = lOut < 11 ? 0.0f : fabsf(alphaOutAbsReg*deltaZLum / z_OutLo);
    const float dBetaLum2 = (dBetaInLum + dBetaOutLum) * (dBetaInLum + dBetaOutLum);
    const float sinDPhi = sinf(dPhi);

    const float dBetaRIn2 = 0; // TODO-RH
    // const float dBetaROut2 = 0; // TODO-RH
    float dBetaROut2 = 0;//TODO-RH
    betaOutCut = asinf(fminf(dr*k2Rinv1GeVf / ptCut, sinAlphaMax)) //FIXME: need faster version
        + (0.02f / sdOut_d) + sqrtf(dBetaLum2 + dBetaMuls*dBetaMuls);

    //Cut #6: The real beta cut
    pass = pass & (fabsf(betaOut) < betaOutCut);

    float pt_betaIn = dr * k2Rinv1GeVf/sinf(betaIn);
    float pt_betaOut = dr * k2Rinv1GeVf / sinf(betaOut);
    float dBetaRes = 0.02f/fminf(sdOut_d,sdIn_d);
    float dBetaCut2 = (dBetaRes*dBetaRes * 2.0f + dBetaMuls * dBetaMuls + dBetaLum2 + dBetaRIn2 + dBetaROut2
            + 0.25f * (fabsf(betaInRHmin - betaInRHmax) + fabsf(betaOutRHmin - betaOutRHmax)) * (fabsf(betaInRHmin - betaInRHmax) + fabsf(betaOutRHmin - betaOutRHmax)));
    float dBeta = betaIn - betaOut;
    //Cut #7: Cut on dBeta
    deltaBetaCut = sqrtf(dBetaCut2);

    pass = pass & (dBeta * dBeta <= dBetaCut2);

    return pass;
}

__device__ void SDL::runDeltaBetaIterations(float& betaIn, float& betaOut, float& betaAv, float & pt_beta, float sdIn_dr, float sdOut_dr, float dr, float lIn)
{
    if (lIn == 0)
    {
        betaOut += copysign(asinf(fminf(sdOut_dr * k2Rinv1GeVf / fabsf(pt_beta), sinAlphaMax)), betaOut);
        return;
    }

    if (betaIn * betaOut > 0.f and (fabsf(pt_beta) < 4.f * pt_betaMax or (lIn >= 11 and fabsf(pt_beta) < 8.f * pt_betaMax)))   //and the pt_beta is well-defined; less strict for endcap-endcap
    {

        const float betaInUpd  = betaIn + copysignf(asinf(fminf(sdIn_dr * k2Rinv1GeVf / fabsf(pt_beta), sinAlphaMax)), betaIn); //FIXME: need a faster version
        const float betaOutUpd = betaOut + copysignf(asinf(fminf(sdOut_dr * k2Rinv1GeVf / fabsf(pt_beta), sinAlphaMax)), betaOut); //FIXME: need a faster version
        betaAv = 0.5f * (betaInUpd + betaOutUpd);

        //1st update
        //pt_beta = dr * k2Rinv1GeVf / sinf(betaAv); //get a better pt estimate
        const float pt_beta_inv = 1.f/fabsf(dr * k2Rinv1GeVf / sinf(betaAv)); //get a better pt estimate

        betaIn  += copysignf(asinf(fminf(sdIn_dr * k2Rinv1GeVf *pt_beta_inv, sinAlphaMax)), betaIn); //FIXME: need a faster version
        betaOut += copysignf(asinf(fminf(sdOut_dr * k2Rinv1GeVf *pt_beta_inv, sinAlphaMax)), betaOut); //FIXME: need a faster version
        //update the av and pt
        betaAv = 0.5f * (betaIn + betaOut);
        //2nd update
        pt_beta = dr * k2Rinv1GeVf / sinf(betaAv); //get a better pt estimate
    }
    else if (lIn < 11 && fabsf(betaOut) < 0.2f * fabsf(betaIn) && fabsf(pt_beta) < 12.f * pt_betaMax)   //use betaIn sign as ref
    {
   
        const float pt_betaIn = dr * k2Rinv1GeVf / sinf(betaIn);

        const float betaInUpd  = betaIn + copysignf(asinf(fminf(sdIn_dr * k2Rinv1GeVf / fabsf(pt_betaIn), sinAlphaMax)), betaIn); //FIXME: need a faster version
        const float betaOutUpd = betaOut + copysignf(asinf(fminf(sdOut_dr * k2Rinv1GeVf / fabsf(pt_betaIn), sinAlphaMax)), betaIn); //FIXME: need a faster version
        betaAv = (fabsf(betaOut) > 0.2f * fabsf(betaIn)) ? (0.5f * (betaInUpd + betaOutUpd)) : betaInUpd;

        //1st update
        pt_beta = dr * k2Rinv1GeVf / sin(betaAv); //get a better pt estimate
        betaIn  += copysignf(asinf(fminf(sdIn_dr * k2Rinv1GeVf / fabsf(pt_beta), sinAlphaMax)), betaIn); //FIXME: need a faster version
        betaOut += copysignf(asinf(fminf(sdOut_dr * k2Rinv1GeVf / fabsf(pt_beta), sinAlphaMax)), betaIn); //FIXME: need a faster version
        //update the av and pt
        betaAv = 0.5f * (betaIn + betaOut);
        //2nd update
        pt_beta = dr * k2Rinv1GeVf / sin(betaAv); //get a better pt estimate

    }
}

void SDL::printTracklet(struct SDL::tracklets& trackletsInGPU, struct SDL::segments& segmentsInGPU, struct SDL::miniDoublets& mdsInGPU, struct SDL::hits& hitsInGPU, struct SDL::modules& modulesInGPU, unsigned int trackletIndex)
{
    unsigned int innerSegmentIndex  = trackletsInGPU.segmentIndices[trackletIndex * 2];
    unsigned int outerSegmentIndex = trackletsInGPU.segmentIndices[trackletIndex * 2 + 1];

    std::cout<<std::endl;
    std::cout<<"tl_betaIn : "<<trackletsInGPU.betaIn[trackletIndex] << std::endl;
    std::cout<<"tl_betaOut : "<<trackletsInGPU.betaOut[trackletIndex] << std::endl;
    std::cout<<"tl_pt_beta : "<<trackletsInGPU.pt_beta[trackletIndex] << std::endl;

    std::cout<<"Inner Segment"<<std::endl;
    std::cout << "------------------------------" << std::endl;
    {
        IndentingOStreambuf indent(std::cout);
        printSegment(segmentsInGPU,mdsInGPU, hitsInGPU, modulesInGPU, innerSegmentIndex);
    }

    std::cout<<"Outer Segment"<<std::endl;
    std::cout << "------------------------------" << std::endl;
    {
        IndentingOStreambuf indent(std::cout);
        printSegment(segmentsInGPU,mdsInGPU, hitsInGPU, modulesInGPU, outerSegmentIndex);
    }
}
