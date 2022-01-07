module eventrate
    implicit none
    real(kind=8) :: qglobal(128)
    contains

    function deventrate(q, wimp, nuc_target, eft)
        use OMP_LIB
        use quadrature
        use kinds
        use constants
        use parameters
        use gaus
        use gausquad
        use crosssection
        use Mmaxbolt
        implicit none
        real(doublep) :: dEventRate
        real(doublep) :: q
        type(particle) :: wimp
        type(nucleus) :: nuc_target
        type(eftheory) :: eft
    
        real(doublep) :: mchi, muT
        real(doublep) :: Nt, units
        real(doublep) :: rhochi
        real(doublep), allocatable :: eftsmall(:,:)
    
        real(doublep) :: v  ! DM velocity variable
        real(doublep) :: dv ! DM differential velocity / lattive spacing
        integer, allocatable :: indx(:)
        integer :: i, j, itmp, ind, norder
        real(doublep) :: ve, v0, vesc, vmin, error
    
        real(doublep) :: relerror
    
        integer :: tid
    
        tid = 1
    ! Don't delete the following line; it's an openMP command, not a comment.
    !$  tid = omp_get_thread_num() + 1
        qglobal(tid) = q 
    
        muT = wimp%mass * nuc_target%mass * mN / (wimp%mass + nuc_target%mass * mN)
    
        ve = vearth * kilometerpersecond
        v0 = vscale * kilometerpersecond
        vesc = vescape * kilometerpersecond
        vmin = q/(2d0*muT)
    
        if (vmin > vesc) then
            dEventRate = 0d0
            return
        end if
    
        !relerror=dspectra(vesc,tid) ! This line prevents a segfault... idk why
        relerror = quadrature_relerr
    
        select case(quadrature_type)
          case(1)
            call gaus8_threadsafe (spectraintegrand1d, vmin, vesc, &
                relerror, deventrate, ind, tid )
          case(2)
            deventrate = gaussquad(spectraintegrand1d, gaussorder, vmin, vesc, tid)
          case default
            stop "Invalid quadrature option."
        end select
    
        Nt = nuc_target%Nt
        rhochi = wimp%localdensity / centimeter**3d0
        Mchi = wimp%mass
        dEventRate = ntscale * kilogramday * Nt * (rhochi/Mchi) * dEventRate *  (pi*v0**2/ve)
      
    end function deventrate
    
    function spectraintegrand1d(vv, tid)
        ! The purpose of this function is to create a callable func for the
        ! adaptive integral routine. Other functions in this program use
        ! (the good practice of) explicit data dependency. An exception
        ! was made for this fuction for compatibility with the adaptive
        ! integration routine used to integrate the event rate spectra.
    
        use main ! This is the only function allowed to use main.
        use kinds
        use constants
        use crosssection
        use mmaxbolt
    
        implicit none
        real(doublep) :: vv, qq, ve, v0
        real(doublep) :: spectraintegrand1d
        integer tid
    
        ve = vearth * kilometerpersecond
        v0 = vscale * kilometerpersecond
        qq = qglobal(tid)
    
        spectraintegrand1d = diffCrossSection(vv, qq, wimp, nuc_target, eft) &
            * vv * vv * ( maxbolt(vv-ve,v0) - maxbolt(vv+ve,v0) )
    
    end function

end module eventrate
