      SUBROUTINE GFLUXV(DTDEL,TDEL,TAUCUMIN,WDEL,CDEL,UBAR0,F0PI,RSF,  &
                        BTOP,BSURF,FMIDP,FMIDM,DIFFV,FLUXUP,FLUXDN,    &
                        detau)

!     GCM v23   2010
!     Ames Mars GCM group
!     Jeffery Hollingsworth, PI
!     NASA Ames Research Center

!  THIS SUBROUTINE TAKES THE OPTICAL CONSTANTS AND BOUNDARY CONDITIONS
!  FOR THE VISIBLE  FLUX AT ONE WAVELENGTH AND SOLVES FOR THE FLUXES AT
!  THE LEVELS. THIS VERSION IS SET UP TO WORK WITH LAYER OPTICAL DEPTHS
!  MEASURED FROM THE TOP OF EACH LAYER.  (DTAU) TOP OF EACH LAYER HAS  
!  OPTICAL DEPTH TAU(N).IN THIS SUB LEVEL N IS ABOVE LAYER N. THAT IS LAYER N
!  HAS LEVEL N ON TOP AND LEVEL N+1 ON BOTTOM. OPTICAL DEPTH INCREASES
!  FROM TOP TO BOTTOM. SEE C.P. MCKAY, TGM NOTES.
! THIS SUBROUTINE DIFFERS FROM ITS IR COUNTERPART IN THAT HERE WE SOLVE FOR 
! THE FLUXES DIRECTLY USING THE GENERALIZED NOTATION OF MEADOR AND WEAVOR
! J.A.S., 37, 630-642, 1980.
! THE TRI-DIAGONAL MATRIX SOLVER IS DSOLVER AND IS DOUBLE PRECISION SO MANY 
! VARIABLES ARE PASSED AS SINGLE THEN BECOME DOUBLE IN DSOLVER
!
! NLL           = NUMBER OF LEVELS (NAYER + 1) THAT WILL BE SOLVED
! NAYER         = NUMBER OF LAYERS (NOTE DIFFERENT SPELLING HERE)
! WAVEN         = WAVELENGTH FOR THE COMPUTATION
! DTDEL(NLAYER) = ARRAY OPTICAL DEPTH OF THE LAYERS
! TDEL(NLL)     = ARRAY COLUMN OPTICAL DEPTH AT THE LEVELS
! WDEL(NLEVEL)  = SINGLE SCATTERING ALBEDO
! CDEL(NLL)     = ASYMMETRY FACTORS, 0=ISOTROPIC
! UBARV         = AVERAGE ANGLE, 
! UBAR0         = SOLAR ZENITH ANGLE
! F0PI          = INCIDENT SOLAR DIRECT BEAM FLUX
! RSF           = SURFACE REFLECTANCE
! BTOP          = UPPER BOUNDARY CONDITION ON DIFFUSE FLUX
! BSURF         = REFLECTED DIRECT BEAM = (1-RSFI)*F0PI*EDP-TAU/U
! FP(NLEVEL)    = UPWARD FLUX AT LEVELS
! FM(NLEVEL)    = DOWNWARD FLUX AT LEVELS
! FMIDP(NLAYER) = UPWARD FLUX AT LAYER MIDPOINTS
! FMIDM(NLAYER) = DOWNWARD FLUX AT LAYER MIDPOINTS
! added Dec 2002
! DIFFV         = downward diffuse solar flux at the surface
! 
!======================================================================!

      use grid_h
      use radinc_h

      implicit none

      integer, parameter :: NLP = 101     ! MUST BE LARGER THAN NLEVEL

      REAL*8 EM, EP
      REAL*8 W0(L_NLAYRAD), COSBAR(L_NLAYRAD), DTAU(L_NLAYRAD)
      REAL*8 TAU(L_NLEVRAD), WDEL(L_NLAYRAD), CDEL(L_NLAYRAD)
      REAL*8 DTDEL(L_NLAYRAD), TDEL(L_NLEVRAD)
      REAL*8 FMIDP(L_NLAYRAD), FMIDM(L_NLAYRAD)
      REAL*8 LAMDA(NLP), ALPHA(NLP), XK1(NLP), XK2(NLP)
      REAL*8 G1(NLP), G2(NLP), G3(NLP), GAMA(NLP), CP(NLP), CM(NLP)
      REAL*8 CPM1(NLP)
      REAL*8 CMM1(NLP), E1(NLP), E2(NLP), E3(NLP), E4(NLP), EXPTRM(NLP)
      REAL*8 FLUXUP, FLUXDN
      REAL*8 FACTOR, TAUCUMIN(L_LEVELS), TAUCUM(L_LEVELS)
      real*8  :: detau

      integer NAYER, L, K
      real*8  ubar0, f0pi, rsf, btop, bsurf, g4, denom, am, ap
      real*8  taumax, taumid, cpmid, cmmid
      real*8  diffv

!======================================================================C
 
      NAYER  = L_NLAYRAD
      TAUMAX = L_TAUMAX    !Default is 35.0
      
!  Delta-Eddington Scaling

      FACTOR    = 1.0D0 - WDEL(1)*CDEL(1)**2

      TAU(1)    = TDEL(1)*FACTOR
      TAUCUM(1) = 0.0D0
      TAUCUM(2) = TAUCUMIN(2)*FACTOR
      TAUCUM(3) = TAUCUM(2) +(TAUCUMIN(3)-TAUCUMIN(2))*FACTOR

      DO L=1,L_NLAYRAD-1
        FACTOR      = 1.0D0 - WDEL(L)*CDEL(L)**2
        W0(L)       = WDEL(L)*(1.0D0-CDEL(L)**2)/FACTOR
        COSBAR(L)   = CDEL(L)/(1.0D0+CDEL(L))
        DTAU(L)     = DTDEL(L)*FACTOR
        TAU(L+1)    = TAU(L)+DTAU(L)
        K           = 2*(L+1)
        TAUCUM(K)   = TAU(L+1)
        TAUCUM(K+1) = TAUCUM(K) + (TAUCUMIN(K+1)-TAUCUMIN(K))*FACTOR
      END DO

!  Bottom layer

      L             = L_NLAYRAD
      FACTOR        = 1.0D0 - WDEL(L)*CDEL(L)**2
      W0(L)         = WDEL(L)*(1.0D0-CDEL(L)**2)/FACTOR
      COSBAR(L)     = CDEL(L)/(1.0D0+CDEL(L))
      DTAU(L)       = DTDEL(L)*FACTOR
      TAU(L+1)      = TAU(L)+DTAU(L)
      TAUCUM(2*L+1) = TAU(L+1)
      detau         = TAUCUM(2*L+1)
 
!     WE GO WITH THE QUADRATURE APPROACH HERE.  THE "SQRT(3)" factors
!     ARE THE UBARV TERM.

      DO L=1,L_NLAYRAD
        
        ALPHA(L)=SQRT( (1.0-W0(L))/(1.0-W0(L)*COSBAR(L)) )

!       SET OF CONSTANTS DETERMINED BY DOM 

        G1(L)    = (SQRT(3.0)*0.5)*(2.0- W0(L)*(1.0+COSBAR(L)))
        G2(L)    = (SQRT(3.0)*W0(L)*0.5)*(1.0-COSBAR(L))
        G3(L)    = 0.5*(1.0-SQRT(3.0)*COSBAR(L)*UBAR0)
        LAMDA(L) = SQRT(G1(L)**2 - G2(L)**2)
        GAMA(L)  = (G1(L)-LAMDA(L))/G2(L)
      END DO

      DO L=1,L_NLAYRAD
        G4    = 1.0-G3(L)
        DENOM = LAMDA(L)**2 - 1./UBAR0**2
 
!       THERE IS A POTENTIAL PROBLEM HERE IF W0=0 AND UBARV=UBAR0
!       THEN DENOM WILL VANISH. THIS ONLY HAPPENS PHYSICALLY WHEN 
!       THE SCATTERING GOES TO ZERO
!       PREVENT THIS WITH AN IF STATEMENT

        IF ( DENOM .EQ. 0.) THEN
          DENOM=1.E-10
        END IF

        AM = F0PI*W0(L)*(G4   *(G1(L)+1./UBAR0) +G2(L)*G3(L) )/DENOM
        AP = F0PI*W0(L)*(G3(L)*(G1(L)-1./UBAR0) +G2(L)*G4    )/DENOM

!       CPM1 AND CMM1 ARE THE CPLUS AND CMINUS TERMS EVALUATED
!       AT THE TOP OF THE LAYER, THAT IS LOWER   OPTICAL DEPTH TAU(L)
 
        CPM1(L) = AP*EXP(-MIN(TAU(L)/UBAR0,MAXEXP))
        CMM1(L) = AM*EXP(-MIN(TAU(L)/UBAR0,MAXEXP))

!       CP AND CM ARE THE CPLUS AND CMINUS TERMS EVALUATED AT THE
!       BOTTOM OF THE LAYER.  THAT IS AT HIGHER OPTICAL DEPTH TAU(L+1)

        CP(L) = AP*EXP(-MIN(TAU(L+1)/UBAR0,MAXEXP))
        CM(L) = AM*EXP(-MIN(TAU(L+1)/UBAR0,MAXEXP))

      END DO
 
!     NOW CALCULATE THE EXPONENTIAL TERMS NEEDED
!     FOR THE TRIDIAGONAL ROTATED LAYERED METHOD

      DO L=1,L_NLAYRAD
        EXPTRM(L) = MIN(TAUMAX,LAMDA(L)*DTAU(L))  ! CLIPPED EXPONENTIAL
        EP = EXP(EXPTRM(L))

        EM        = 1.0/EP
        E1(L)     = EP+GAMA(L)*EM
        E2(L)     = EP-GAMA(L)*EM
        E3(L)     = GAMA(L)*EP+EM
        E4(L)     = GAMA(L)*EP-EM
      END DO
 
      CALL DSOLVER(NAYER,GAMA,CP,CM,CPM1,CMM1,E1,E2,E3,E4,BTOP,        &
                   BSURF,RSF,XK1,XK2)

!     NOW WE CALCULATE THE FLUXES AT THE MIDPOINTS OF THE LAYERS.
 
      DO L=1,L_NLAYRAD-1
        EXPTRM(L) = MIN(TAUMAX,LAMDA(L)*(TAUCUM(2*L+1)-TAUCUM(2*L)))
 
        EP = EXP(EXPTRM(L))

        EM    = 1.0/EP
        G4    = 1.0-G3(L)
        DENOM = LAMDA(L)**2 - 1./UBAR0**2

!       THERE IS A POTENTIAL PROBLEM HERE IF W0=0 AND UBARV=UBAR0
!       THEN DENOM WILL VANISH. THIS ONLY HAPPENS PHYSICALLY WHEN 
!       THE SCATTERING GOES TO ZERO
!       PREVENT THIS WITH A IF STATEMENT

        IF ( DENOM .EQ. 0.) THEN
          DENOM=1.E-10
        END IF

        AM = F0PI*W0(L)*(G4   *(G1(L)+1./UBAR0) +G2(L)*G3(L) )/DENOM
        AP = F0PI*W0(L)*(G3(L)*(G1(L)-1./UBAR0) +G2(L)*G4    )/DENOM

!       CPMID AND CMMID  ARE THE CPLUS AND CMINUS TERMS EVALUATED
!       AT THE MIDDLE OF THE LAYER.

        TAUMID   = TAUCUM(2*L+1)

        CPMID = AP*EXP(-MIN(TAUMID/UBAR0,MAXEXP))
        CMMID = AM*EXP(-MIN(TAUMID/UBAR0,MAXEXP))

        FMIDP(L) = XK1(L)*EP + GAMA(L)*XK2(L)*EM + CPMID
        FMIDM(L) = XK1(L)*EP*GAMA(L) + XK2(L)*EM + CMMID
 
!       ADD THE DIRECT FLUX TO THE DOWNWELLING TERM

        FMIDM(L)= FMIDM(L)+UBAR0*F0PI*EXP(-MIN(TAUMID/UBAR0,MAXEXP))
   
      END DO
 
!     FLUX AT THE top layer

      EP    = 1.0
      EM    = 1.0
      G4    = 1.0-G3(1)
      DENOM = LAMDA(1)**2 - 1./UBAR0**2

!     THERE IS A POTENTIAL PROBLEM HERE IF W0=0 AND UBARV=UBAR0
!     THEN DENOM WILL VANISH. THIS ONLY HAPPENS PHYSICALLY WHEN 
!     THE SCATTERING GOES TO ZERO
!     PREVENT THIS WITH A IF STATEMENT

      IF ( DENOM .EQ. 0.) THEN
        DENOM=1.E-10
      END IF

      AM = F0PI*W0(1)*(G4   *(G1(1)+1./UBAR0) +G2(1)*G3(1) )/DENOM
      AP = F0PI*W0(1)*(G3(1)*(G1(1)-1./UBAR0) +G2(1)*G4    )/DENOM

!     CPMID AND CMMID  ARE THE CPLUS AND CMINUS TERMS EVALUATED
!     AT THE MIDDLE OF THE LAYER.

      CPMID  = AP
      CMMID  = AM

      FLUXUP = XK1(1)*EP + GAMA(1)*XK2(1)*EM + CPMID
      FLUXDN = XK1(1)*EP*GAMA(1) + XK2(1)*EM + CMMID

!     ADD THE DIRECT FLUX TO THE DOWNWELLING TERM

      fluxdn = fluxdn+UBAR0*F0PI*EXP(-MIN(TAUCUM(1)/UBAR0,MAXEXP))
 
!     This is for the "special" bottom layer, where we take
!     DTAU instead of DTAU/2.

      L     = L_NLAYRAD 
      EXPTRM(L) = MIN(TAUMAX,LAMDA(L)*(TAUCUM(L_LEVELS)-               &
                                       TAUCUM(L_LEVELS-1)))

      EP    = EXP(EXPTRM(L))
      EM    = 1.0/EP
      G4    = 1.0-G3(L)
      DENOM = LAMDA(L)**2 - 1./UBAR0**2

!     THERE IS A POTENTIAL PROBLEM HERE IF W0=0 AND UBARV=UBAR0
!     THEN DENOM WILL VANISH. THIS ONLY HAPPENS PHYSICALLY WHEN 
!     THE SCATTERING GOES TO ZERO
!     PREVENT THIS WITH A IF STATEMENT

      IF ( DENOM .EQ. 0.) THEN
        DENOM=1.E-10
      END IF

      AM = F0PI*W0(L)*(G4   *(G1(L)+1./UBAR0) +G2(L)*G3(L) )/DENOM
      AP = F0PI*W0(L)*(G3(L)*(G1(L)-1./UBAR0) +G2(L)*G4    )/DENOM

!     CPMID AND CMMID  ARE THE CPLUS AND CMINUS TERMS EVALUATED
!     AT THE MIDDLE OF THE LAYER.

      TAUMID   = MIN(TAUCUM(L_LEVELS),TAUMAX)
      CPMID    = AP*EXP(-MIN(TAUMID/UBAR0,MAXEXP))
      CMMID    = AM*EXP(-MIN(TAUMID/UBAR0,MAXEXP))

      FMIDP(L) = XK1(L)*EP + GAMA(L)*XK2(L)*EM + CPMID
      FMIDM(L) = XK1(L)*EP*GAMA(L) + XK2(L)*EM + CMMID

!  Save the diffuse downward flux for TEMPGR calculations

      DIFFV = FMIDM(L)
 
!     ADD THE DIRECT FLUX TO THE DOWNWELLING TERM

      FMIDM(L)= FMIDM(L)+UBAR0*F0PI*EXP(-MIN(TAUMID/UBAR0,MAXEXP))


      RETURN
      end subroutine gfluxv
