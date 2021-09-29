module mod_spectra

    use kinds
    implicit none

    real(doublep) :: x_start
    real(doublep) :: x_stop
    real(doublep) :: x_step
    real(doublep), allocatable :: x_grid(:), energy_grid(:), momentum_grid(:)
    integer :: energy_grid_size

contains

function velocitycurve(vlist, q, wimp, nuc_target, eft, option)
    use crosssection
    use transition
    use parameters
    implicit none
    real(doublep) :: q, v
    real(doublep), dimension(:) :: vlist
    type(particle) :: wimp
    type(nucleus) :: nuc_target
    type(eftheory) :: eft
    integer :: option

    real(doublep), dimension(size(vlist)) :: velocitycurve

    integer :: i

    select case(option)
    case(3)
        do i = 1, size(vlist)
            v = vlist(i)
            velocitycurve(i) = transition_probability(q, v, wimp, nuc_target, eft)
!            call progressmessage(100*real(i)/real(size(vlist)))
        end do
    case(2)
        do i = 1, size(vlist)
            v = vlist(i)
            velocitycurve(i) = diffCrossSection(v, q, wimp, nuc_target, eft)
!            call progressmessage(100*real(i)/real(size(vlist)))
        end do        
    case default
        stop "Not a velocity curve option."
    end select
end function velocitycurve


subroutine velocity_curve(wimp, nuc_target, eft, option)
    use parameters
    use constants, only: kev, mN, kilometerpersecond
    implicit none

    type(particle) :: wimp
    type(nucleus) :: nuc_target
    type(eftheory) :: eft    
    real(doublep) :: Er, Qr, vstart, vstop, vstep
    integer :: sizevlist, i
    real(doublep), allocatable :: vlist(:), cslist(:)
    integer :: option, iunit

    print*,"Enter recoil E (keV):"
    read*,Er
    print '("Er = ",F8.4," (keV)")',Er
    Qr = sqrt(2d0*nuc_target%mass*mN*er*kev)
    print '("Qr = ",F8.4,"(GeV/c)")',qr
    print '("Vmin = ",F8.4,"(km/s)")',1/kilometerpersecond&
        *qr/(2.0* wimp%mass * nuc_target%mass * mN / (wimp%mass + nuc_target%mass * mN))

    print*,"Enter start v (km/s):"
    read*,vstart
    print '("v start = ",F8.4," (km/s)")',vstart
    vstart = vstart * kilometerpersecond
    print '("v start = ",ES12.4," (c)")',vstart

    print*,"Enter stop v (km/s):"
    read*,vstop
    print '("v stop = ",F12.4," (km/s)")',vstop
    vstop = vstop * kilometerpersecond
    print '("v stop = ",ES12.4," (c)")',vstop

    print*,"Enter step v (km/s):"
    read*,vstep
    print '("v step = ",F8.4," (km/s)")',vstep
    vstep = vstep * kilometerpersecond
    print '("v step = ",ES12.4," (c)")',vstep

    sizevlist = int(abs(vstop - vstart)/vstep)
    allocate(vlist(sizevlist))
    allocate(cslist(sizevlist))
    do i = 1, sizevlist
        vlist(i) = vstart + (i-1) * vstep
    end do


    cslist = velocitycurve(vlist, qr, wimp, nuc_target, eft, option)

    select case(option)
    case(3)
        open(newunit=iunit, file="transition_probability.dat")
        do i = 1, sizevlist
            write(iunit,*) vlist(i)/kilometerpersecond, cslist(i)
        end do
        close(iunit)
    case(2)
        open(newunit=iunit, file="crosssection.dat")
        do i = 1, sizevlist
            write(iunit,*) vlist(i)/kilometerpersecond, cslist(i)
        end do
        close(iunit)
    case default
        STOP "Not a velocity curve option."
    end select        
    
end subroutine

function spectra(momenta, wimp, nuc_target, eft)
    use parameters
    use eventrate
    implicit none
    real(doublep), dimension(:) :: momenta
    type(particle) :: wimp
    type(nucleus) :: nuc_target
    type(eftheory) :: eft
    real(doublep), dimension(size(momenta)) :: spectra

    integer :: i, N
    real(doublep) :: q

    N = size(momenta)
    !$OMP parallel do private(q) schedule(dynamic, 1)
    do i = 1, N
        q = momenta(i)
        spectra(i) = dEventRate(q, wimp, nuc_target, eft)
        !call progressmessage(100*real(i)/real(N))
    end do
    !$OMP end parallel do
    !$OMP barrier

end function spectra

subroutine eventrate_spectra(wimp, nuc_target, eft)
    use constants
    use momenta
    use parameters

    implicit none

    type(particle) :: wimp
    type(nucleus) :: nuc_target
    type(eftheory) :: eft
    
    integer :: calc_num
    integer :: iunit
    real(doublep) :: recoil_energy, momentum_transfer
    real(doublep), allocatable :: event_rate_spectra(:)
    real(doublep) :: mtarget, totaleventrate, error

    print*,"Computing differential event rate spectra"

    ! Get parameters
    mtarget = nuc_target%mass

    ! Get domain
    call get_energy_grid(mtarget)

    ! Setup calculation and compute
    print*,'Number of event rates to compute:',energy_grid_size
    allocate(event_rate_spectra(energy_grid_size))

    event_rate_spectra = spectra(momentum_grid, wimp, nuc_target, eft)

    call boole(energy_grid_size, momentum_grid, momentum_grid*Event_rate_spectra/(mn*mtarget),&
        totaleventrate)
    

    write(6,"(A,T30,A,T56,A)")" E-recoil (kev)","q-transfer (gev/c)","Eventrate (events/gev)"
    do calc_num = 1, energy_grid_size
        momentum_transfer = momentum_grid(calc_num)
        recoil_energy = energy_grid(calc_num)
        print*,recoil_energy,momentum_transfer,event_rate_spectra(calc_num)
    end do

    print*,'Total integrated eventrate (events)',totaleventrate,'pm',error

    ! Write results to file
    open(newunit=iunit, file='eventrate_spectra.dat')
    write(iunit,"(A,T30,A)")"# Recoil energy (kev)","Event rate (events/gev)"
    do calc_num = 1, energy_grid_size
        recoil_energy = energy_grid(calc_num)
        write(iunit,*)recoil_energy,event_rate_spectra(calc_num)
    end do

    close(iunit)
    print*,"Event rate spectra written to eventrate_spectra.dat"

end subroutine eventrate_spectra

subroutine get_energy_grid(mtarget)
    use momenta
    use constants, only: kev, mN
    implicit none
    integer :: calc_num
    character(len=100) :: filename
    real(doublep) :: momentum_transfer, mtarget, recoil_energy

    ! Get recoil energy grid from user or from file
    if (useenergyfile) then
        print*,'Recoil energies will be read from file. Enter filename:'
        read*,filename
        call read_energy_grid(filename)
    else
        if (usemomentum) then
            print*,'What is the range of transfer momenta?'
            print*,'Enter starting momentum, stopping momentum, setp size:'
        else
            print*,'What is the range of recoil energies in kev?'
            print*,'Enter starting energy, stoping energy, step size:'
        end if

        read*,x_start, x_stop, x_step

        if (usemomentum) then
            print*,"q min  (gec/c)",x_start
            print*,"q max  (gev/c)",x_stop
            print*,"q step (gev/c)",x_step
        else
            print*,"E min  (kev)",x_start
            print*,"E max  (kev)",x_stop
            print*,"E step (kev)",x_step
        end if        

        energy_grid_size = int((x_stop - x_start) / x_step) + 1

        allocate(energy_grid(energy_grid_size))
        do calc_num = 1, energy_grid_size
            energy_grid(calc_num) = x_start + (calc_num - 1) * x_step
        end do
    end if

    allocate(momentum_grid(energy_grid_size))
    do calc_num = 1, energy_grid_size
        if (usemomentum) then
            momentum_transfer = x_start + (calc_num - 1) * x_step
            recoil_energy = momentum_transfer**2d0 / (2d0*mtarget*mN*kev)
            momentum_grid(calc_num) = momentum_transfer
            energy_grid(calc_num) = recoil_energy
        else
            recoil_energy = energy_grid(calc_num)
            momentum_grid(calc_num) = sqrt(2d0*mtarget*mN*recoil_energy*kev)
        end if
    end do    
end subroutine

subroutine read_energy_grid(filename)

    use kinds
    implicit none
    character(len=100) :: filename
    integer :: i, io, iunit

    open(newunit=iunit,file=trim(filename))
    do 
        read(iunit,*,iostat=io)
        if (io/=0) exit
        energy_grid_size = energy_grid_size + 1
    end do

    allocate(energy_grid(energy_grid_size))
    rewind(iunit)

    do i = 1, energy_grid_size
        read(iunit,*) energy_grid(i)
    end do
    close(iunit)
end subroutine read_energy_grid

end module mod_spectra

