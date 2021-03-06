module update_module

  use datatypes_module
  use grid_module
  use variables_module
  use params_module

  implicit none

  private

  public :: update

contains
  
  subroutine update(U, g, fluxes, godunov_state, dt)

    type(gridvar_t),     intent(inout) :: U, g
    type(gridedgevar_t), intent(inout) :: fluxes
    type(gridedgevar_t), intent(in   ) :: godunov_state
    real (kind=dp_t),    intent(in   ) :: dt

    type(gridvar_t) :: Uold
    real (kind=dp_t) :: avisco, divU

    integer :: i

    ! store the old state
    call build(Uold, U%grid, U%nvar)
    do i = U%grid%lo, U%grid%hi
       Uold%data(i,:) = U%data(i,:)
    enddo

    ! artifical viscosity
    do i = U%grid%lo, U%grid%hi+1
       divU = (U%data(i,iumomx) / U%data(i,iudens) - &
               U%data(i-1,iumomx) / U%data(i-1,iudens))
       avisco = cvisc*max(-divU, ZERO)

       fluxes%data(i,:) = fluxes%data(i,:) + avisco*(U%data(i-1,:) - U%data(i,:))
    enddo
    

    ! this is (A_l F_l - A_r F_r)/dV + any gradient terms
    do i = U%grid%lo, U%grid%hi
       U%data(i,:) = U%data(i,:) + &
            (dt/U%grid%dV(i))*(U%grid%Al(i)  *fluxes%data(i,  :) - &
                               U%grid%Al(i+1)*fluxes%data(i+1,:)) 

       if (U%grid%geometry == 1) then
          U%data(i,iumomx) = U%data(i,iumomx) - &
            (dt/U%grid%dx)*(godunov_state%data(i+1,iqpres) - &
                            godunov_state%data(i  ,iqpres))
       endif
    enddo


    ! time-centered source terms (note: gravity is NOT currently time-centered)
    do i = U%grid%lo, U%grid%hi
       U%data(i,iumomx) = U%data(i,iumomx) + &
            0.5_dp_t*dt*(U%data(i,iudens) + Uold%data(i,iudens))*g%data(i,1)

       U%data(i,iuener) = U%data(i,iuener) + &
            0.5_dp_t*dt*(U%data(i,iumomx) + Uold%data(i,iumomx))*g%data(i,1)
    enddo


    ! clean-up
    call destroy(Uold)


  end subroutine update

end module update_module
