
  program multiply_CUBIT_Abaqus_mesh

! Dimitri Komatitsch, University of Pau, France, February 2009.

! multiply a CUBIT mesh stored in Abaqus ASCII format by 1000
! to convert it from km to m

  implicit none

! character(len=100), parameter :: cubit_mesh_file = 'HOMOGENE_3D_lisse_300_in_meters.inp'
! integer, parameter :: NPOIN = 98692

! character(len=100), parameter :: cubit_mesh_file = 'regolite_3D_rego3d_70m_in_meters.inp'
! integer, parameter :: NPOIN = 4050696

! character(len=100), parameter :: cubit_mesh_file = 'HOMOGENE_2D_in_meters.inp'
! integer, parameter :: NPOIN = 3882

! character(len=100), parameter :: cubit_mesh_file = 'eros_complexe_2d_regolite_fractures_modifie_in_meters.inp'
! integer, parameter :: NPOIN = 57807

! character(len=100), parameter :: cubit_mesh_file = 'REGOLITE_only_no_fractures_2D_in_meters.inp'
! integer, parameter :: NPOIN = 32536

  character(len=100), parameter :: cubit_mesh_file = 'rego3d_70_disp.inp'
  integer, parameter :: NPOIN = 5924713

  real, dimension(NPOIN) :: x,y,z

  integer :: i,iread

! read the mesh
  open(unit=10,file=cubit_mesh_file,status='unknown',action='read')

! skip the header
  read(10,*)
  read(10,*)
  read(10,*)

! read the points
  do i = 1,NPOIN
    read(10,*) iread,x(i),y(i),z(i)
    if(iread /= i) then
      print *,'error at i,iread = ',i,iread
      stop 'wrong input for a point'
    endif
    print *,iread,',',x(i)*1000,',',y(i)*1000,',',z(i)*1000
  enddo

  close(10)

  end program multiply_CUBIT_Abaqus_mesh
