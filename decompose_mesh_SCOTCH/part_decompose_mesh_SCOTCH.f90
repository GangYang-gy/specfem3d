module part_decompose_mesh_SCOTCH

  implicit none

contains

  !-----------------------------------------------
  ! Creating dual graph (adjacency is defined by 'ncommonnodes' between two elements).
  !-----------------------------------------------
  subroutine mesh2dual_ncommonnodes(nelmnts, nnodes, nsize, sup_neighbour, elmnts, xadj, adjncy, &
 nnodes_elmnts, nodes_elmnts, max_neighbour, ncommonnodes)

    include './constants_decompose_mesh_SCOTCH.h'

    integer(long), intent(in)  :: nelmnts
    integer, intent(in)  :: nnodes
    integer(long), intent(in)  :: nsize
    integer(long), intent(in)  :: sup_neighbour
    integer, dimension(0:esize*nelmnts-1), intent(in)  :: elmnts
    integer, dimension(0:nelmnts)  :: xadj
    integer, dimension(0:sup_neighbour*nelmnts-1)  :: adjncy
    integer, dimension(0:nnodes-1)  :: nnodes_elmnts
    integer, dimension(0:nsize*nnodes-1)  :: nodes_elmnts
    integer, intent(out) :: max_neighbour
    integer, intent(in)  :: ncommonnodes

    integer  :: i, j, k, l, m, nb_edges
    logical  ::  is_neighbour
    integer  :: num_node, n
    integer  :: elem_base, elem_target
    integer  :: connectivity


    ! initializes
    xadj(:) = 0
    adjncy(:) = 0
    nnodes_elmnts(:) = 0
    nodes_elmnts(:) = 0
    nb_edges = 0

    ! list of elements per node
    do i = 0, esize*nelmnts-1
       nodes_elmnts(elmnts(i)*nsize+nnodes_elmnts(elmnts(i))) = i/esize
       nnodes_elmnts(elmnts(i)) = nnodes_elmnts(elmnts(i)) + 1

    end do

    ! checking which elements are neighbours ('ncommonnodes' criteria)
    do j = 0, nnodes-1
       do k = 0, nnodes_elmnts(j)-1
          do l = k+1, nnodes_elmnts(j)-1

             connectivity = 0
             elem_base = nodes_elmnts(k+j*nsize)
             elem_target = nodes_elmnts(l+j*nsize)
             do n = 1, esize
                num_node = elmnts(esize*elem_base+n-1)
                do m = 0, nnodes_elmnts(num_node)-1
                   if ( nodes_elmnts(m+num_node*nsize) == elem_target ) then
                      connectivity = connectivity + 1
                   end if
                end do
             end do

             if ( connectivity >=  ncommonnodes) then

                is_neighbour = .false.

                do m = 0, xadj(nodes_elmnts(k+j*nsize))
                   if ( .not.is_neighbour ) then
                      if ( adjncy(nodes_elmnts(k+j*nsize)*sup_neighbour+m) == nodes_elmnts(l+j*nsize) ) then
                         is_neighbour = .true.

                      end if
                   end if
                end do
                if ( .not.is_neighbour ) then
                   adjncy(nodes_elmnts(k+j*nsize)*sup_neighbour+xadj(nodes_elmnts(k+j*nsize))) = nodes_elmnts(l+j*nsize)
                   xadj(nodes_elmnts(k+j*nsize)) = xadj(nodes_elmnts(k+j*nsize)) + 1
                   if (xadj(nodes_elmnts(k+j*nsize))>sup_neighbour) stop 'ERROR : too much neighbours per element, modify the mesh.'
                   adjncy(nodes_elmnts(l+j*nsize)*sup_neighbour+xadj(nodes_elmnts(l+j*nsize))) = nodes_elmnts(k+j*nsize)
                   xadj(nodes_elmnts(l+j*nsize)) = xadj(nodes_elmnts(l+j*nsize)) + 1
                   if (xadj(nodes_elmnts(l+j*nsize))>sup_neighbour) stop 'ERROR : too much neighbours per element, modify the mesh.'
                end if
             end if
          end do
       end do
    end do

    max_neighbour = maxval(xadj)

    ! making adjacency arrays compact (to be used for partitioning)
    do i = 0, nelmnts-1
       k = xadj(i)
       xadj(i) = nb_edges
       do j = 0, k-1
          adjncy(nb_edges) = adjncy(i*sup_neighbour+j)
          nb_edges = nb_edges + 1
       end do
    end do

    xadj(nelmnts) = nb_edges


  end subroutine mesh2dual_ncommonnodes



  !--------------------------------------------------
  ! construct local numbering for the elements in each partition
  !--------------------------------------------------
  subroutine Construct_glob2loc_elmnts(nelmnts, part, glob2loc_elmnts)

    include './constants_decompose_mesh_SCOTCH.h'

    integer(long), intent(in)  :: nelmnts
    integer, dimension(0:nelmnts-1), intent(in)  :: part
    integer, dimension(:), pointer  :: glob2loc_elmnts

    integer  :: num_glob, num_part
    integer, dimension(0:nparts-1)  :: num_loc

    ! allocates local numbering array
    allocate(glob2loc_elmnts(0:nelmnts-1))

    ! initializes number of local points per partition
    do num_part = 0, nparts-1
       num_loc(num_part) = 0
    end do

    ! local numbering
    do num_glob = 0, nelmnts-1
       ! gets partition
       num_part = part(num_glob)
       ! increments local numbering of elements (starting with 0,1,2,...)
       glob2loc_elmnts(num_glob) = num_loc(num_part)
       num_loc(num_part) = num_loc(num_part) + 1
    end do


  end subroutine Construct_glob2loc_elmnts



  !--------------------------------------------------
  ! construct local numbering for the nodes in each partition
  !--------------------------------------------------
  subroutine Construct_glob2loc_nodes(nelmnts, nnodes, nsize, nnodes_elmnts, nodes_elmnts, part, &
       glob2loc_nodes_nparts, glob2loc_nodes_parts, glob2loc_nodes)

    include './constants_decompose_mesh_SCOTCH.h'

    integer(long), intent(in)  :: nelmnts, nsize
    integer, intent(in)  :: nnodes
    integer, dimension(0:nelmnts-1), intent(in)  :: part
    integer, dimension(0:nnodes-1), intent(in)  :: nnodes_elmnts
    integer, dimension(0:nsize*nnodes-1), intent(in)  :: nodes_elmnts
    integer, dimension(:), pointer  :: glob2loc_nodes_nparts
    integer, dimension(:), pointer  :: glob2loc_nodes_parts
    integer, dimension(:), pointer  :: glob2loc_nodes

    integer  :: num_node
    integer  :: el
    integer  ::  num_part
    integer  ::  size_glob2loc_nodes
    integer, dimension(0:nparts-1)  :: parts_node
    integer, dimension(0:nparts-1)  :: num_parts

    allocate(glob2loc_nodes_nparts(0:nnodes))

    size_glob2loc_nodes = 0
    parts_node(:) = 0

    do num_node = 0, nnodes-1
       glob2loc_nodes_nparts(num_node) = size_glob2loc_nodes
       do el = 0, nnodes_elmnts(num_node)-1
          parts_node(part(nodes_elmnts(el+nsize*num_node))) = 1

       end do

       do num_part = 0, nparts-1
          if ( parts_node(num_part) == 1 ) then
             size_glob2loc_nodes = size_glob2loc_nodes + 1
             parts_node(num_part) = 0

          end if
       end do

    end do

    glob2loc_nodes_nparts(nnodes) = size_glob2loc_nodes

    allocate(glob2loc_nodes_parts(0:glob2loc_nodes_nparts(nnodes)-1))
    allocate(glob2loc_nodes(0:glob2loc_nodes_nparts(nnodes)-1))

    glob2loc_nodes(0) = 0

    parts_node(:) = 0
    num_parts(:) = 0
    size_glob2loc_nodes = 0


    do num_node = 0, nnodes-1
       do el = 0, nnodes_elmnts(num_node)-1
          parts_node(part(nodes_elmnts(el+nsize*num_node))) = 1

       end do
       do num_part = 0, nparts-1

          if ( parts_node(num_part) == 1 ) then
             glob2loc_nodes_parts(size_glob2loc_nodes) = num_part
             glob2loc_nodes(size_glob2loc_nodes) = num_parts(num_part)
             size_glob2loc_nodes = size_glob2loc_nodes + 1
             num_parts(num_part) = num_parts(num_part) + 1
             parts_node(num_part) = 0
          end if

       end do
    end do


  end subroutine Construct_glob2loc_nodes



  !--------------------------------------------------
  ! Construct interfaces between each partitions.
  ! Two adjacent elements in distinct partitions make an entry in array tab_interfaces :
  ! 1/ first element, 2/ second element, 3/ number of common nodes, 4/ first node,
  ! 5/ second node, if relevant.
  ! No interface between acoustic and elastic elements.
  ! Elements with undefined material are considered as elastic elements.
  !--------------------------------------------------
   subroutine Construct_interfaces(nelmnts, sup_neighbour, part, elmnts, xadj, adjncy, &
     tab_interfaces, tab_size_interfaces, ninterfaces, nb_materials, cs_material, num_material)

     include './constants_decompose_mesh_SCOTCH.h'

    integer(long), intent(in)  :: nelmnts, sup_neighbour
    integer, dimension(0:nelmnts-1), intent(in)  :: part
    integer, dimension(0:esize*nelmnts-1), intent(in)  :: elmnts
    integer, dimension(0:nelmnts), intent(in)  :: xadj
    integer, dimension(0:sup_neighbour*nelmnts-1), intent(in)  :: adjncy
    integer, dimension(:),pointer  :: tab_size_interfaces, tab_interfaces
    integer, intent(out)  :: ninterfaces
    integer, dimension(1:nelmnts), intent(in)  :: num_material
    double precision, dimension(1:nb_materials), intent(in)  :: cs_material
    integer, intent(in)  :: nb_materials


    integer  :: num_part, num_part_bis, el, el_adj, num_interface, num_edge, ncommon_nodes, &
         num_node, num_node_bis
    integer  :: i, j
    logical  :: is_acoustic_el, is_acoustic_el_adj

    ninterfaces = 0
    do  i = 0, nparts-1
       do j = i+1, nparts-1
          ninterfaces = ninterfaces + 1
       end do
    end do

    allocate(tab_size_interfaces(0:ninterfaces))
    tab_size_interfaces(:) = 0

    num_interface = 0
    num_edge = 0

    do num_part = 0, nparts-1
       do num_part_bis = num_part+1, nparts-1
          do el = 0, nelmnts-1
             if ( part(el) == num_part ) then
                if(num_material(el+1) > 0) then
                   if ( cs_material(num_material(el+1)) < TINYVAL) then
                      is_acoustic_el = .true.
                   else
                      is_acoustic_el = .false.
                   end if
                else
                   is_acoustic_el = .false.
                end if
                do el_adj = xadj(el), xadj(el+1)-1
                   if(num_material(adjncy(el_adj)+1) > 0) then
                      if ( cs_material(num_material(adjncy(el_adj)+1)) < TINYVAL) then
                         is_acoustic_el_adj = .true.
                      else
                         is_acoustic_el_adj = .false.
                      end if
                   else
                      is_acoustic_el_adj = .false.
                   end if
                   if ( (part(adjncy(el_adj)) == num_part_bis) .and. (is_acoustic_el .eqv. is_acoustic_el_adj) ) then
                      num_edge = num_edge + 1

                   end if
                end do
             end if
          end do
          tab_size_interfaces(num_interface+1) = tab_size_interfaces(num_interface) + num_edge
          num_edge = 0
          num_interface = num_interface + 1

       end do
    end do

    num_interface = 0
    num_edge = 0

    allocate(tab_interfaces(0:(tab_size_interfaces(ninterfaces)*7-1)))
    tab_interfaces(:) = 0

    do num_part = 0, nparts-1
       do num_part_bis = num_part+1, nparts-1
          do el = 0, nelmnts-1
             if ( part(el) == num_part ) then
                if(num_material(el+1) > 0) then
                   if ( cs_material(num_material(el+1)) < TINYVAL) then
                      is_acoustic_el = .true.
                   else
                      is_acoustic_el = .false.
                   end if
                else
                   is_acoustic_el = .false.
                end if
                do el_adj = xadj(el), xadj(el+1)-1
                   if(num_material(adjncy(el_adj)+1) > 0) then
                      if ( cs_material(num_material(adjncy(el_adj)+1)) < TINYVAL) then
                         is_acoustic_el_adj = .true.
                      else
                         is_acoustic_el_adj = .false.
                      end if
                   else
                      is_acoustic_el_adj = .false.
                   end if
                   if ( (part(adjncy(el_adj)) == num_part_bis) .and. (is_acoustic_el .eqv. is_acoustic_el_adj) ) then
                      tab_interfaces(tab_size_interfaces(num_interface)*7+num_edge*7+0) = el
                      tab_interfaces(tab_size_interfaces(num_interface)*7+num_edge*7+1) = adjncy(el_adj)
                      ncommon_nodes = 0
                      do num_node = 0, esize-1
                         do num_node_bis = 0, esize-1
                            if ( elmnts(el*esize+num_node) == elmnts(adjncy(el_adj)*esize+num_node_bis) ) then
                               tab_interfaces(tab_size_interfaces(num_interface)*7+num_edge*7+3+ncommon_nodes) &
                                    = elmnts(el*esize+num_node)
                               ncommon_nodes = ncommon_nodes + 1
                            end if
                         end do
                      end do
                      if ( ncommon_nodes > 0 ) then
                         tab_interfaces(tab_size_interfaces(num_interface)*7+num_edge*7+2) = ncommon_nodes
                      else
                         print *, "Error while building interfaces!", ncommon_nodes
                      end if
                      num_edge = num_edge + 1
                   end if
                end do
             end if

          end do
          num_edge = 0
          num_interface = num_interface + 1
       end do
    end do


  end subroutine Construct_interfaces



  !--------------------------------------------------
  ! Write nodes (their coordinates) pertaining to iproc partition in the corresponding Database
  !--------------------------------------------------
  subroutine write_glob2loc_nodes_database(IIN_database, iproc, npgeo, nodes_coords, glob2loc_nodes_nparts, glob2loc_nodes_parts, &
       glob2loc_nodes, nnodes, num_phase)

    integer, intent(in)  :: IIN_database
    integer, intent(in)  :: nnodes, iproc, num_phase
    integer, intent(inout)  :: npgeo

    double precision, dimension(3,nnodes)  :: nodes_coords
    integer, dimension(:), pointer  :: glob2loc_nodes_nparts
    integer, dimension(:), pointer  :: glob2loc_nodes_parts
    integer, dimension(:), pointer  :: glob2loc_nodes

    integer  :: i, j

    if ( num_phase == 1 ) then
       npgeo = 0

       do i = 0, nnodes-1
          do j = glob2loc_nodes_nparts(i), glob2loc_nodes_nparts(i+1)-1
             if ( glob2loc_nodes_parts(j) == iproc ) then
                npgeo = npgeo + 1

             end if

          end do
       end do
    else
       do i = 0, nnodes-1
          do j = glob2loc_nodes_nparts(i), glob2loc_nodes_nparts(i+1)-1
             if ( glob2loc_nodes_parts(j) == iproc ) then
                write(IIN_database,*) glob2loc_nodes(j)+1, nodes_coords(1,i+1), nodes_coords(2,i+1), nodes_coords(3,i+1)
             end if
          end do
       end do
    end if

  end subroutine Write_glob2loc_nodes_database


  !--------------------------------------------------
  ! Write material properties in the Database
  !--------------------------------------------------
  subroutine write_material_properties_database(IIN_database,count_def_mat,count_undef_mat, mat_prop, undef_mat_prop) 

    integer, intent(in)  :: IIN_database
    integer, intent(in)  :: count_def_mat,count_undef_mat
    double precision, dimension(5,count_def_mat)  :: mat_prop
    character (len=30), dimension(5,count_undef_mat) :: undef_mat_prop
    integer  :: i

    write(IIN_database,*)  count_def_mat,count_undef_mat 
    do i = 1, count_def_mat
      ! format:                          # rho                  # vp                    # vs                    # Q_flag             # 0     
       write(IIN_database,*) mat_prop(1,i), mat_prop(2,i), mat_prop(3,i), mat_prop(4,i), mat_prop(5,i)
    end do
    do i = 1, count_undef_mat
       write(IIN_database,*) trim(undef_mat_prop(1,i)),trim(undef_mat_prop(2,i)),trim(undef_mat_prop(3,i)), & 
            trim(undef_mat_prop(4,i)),trim(undef_mat_prop(5,i))
    end do

  end subroutine  write_material_properties_database


  !--------------------------------------------------
  ! Write elements on boundaries (and their four nodes on boundaries) pertaining to iproc partition in the corresponding Database
  !--------------------------------------------------
  subroutine write_boundaries_database(IIN_database, iproc, nelmnts, nspec2D_xmin, nspec2D_xmax, &
       nspec2D_ymin, nspec2D_ymax, nspec2D_bottom, nspec2D_top, &
       ibelm_xmin, ibelm_xmax, ibelm_ymin, ibelm_ymax, ibelm_bottom, ibelm_top, &
       nodes_ibelm_xmin, nodes_ibelm_xmax, nodes_ibelm_ymin, nodes_ibelm_ymax, nodes_ibelm_bottom, nodes_ibelm_top, & 
       glob2loc_elmnts, glob2loc_nodes_nparts, glob2loc_nodes_parts, glob2loc_nodes, part)
     
    include './constants_decompose_mesh_SCOTCH.h'

    integer, intent(in)  :: IIN_database
    integer, intent(in)  :: iproc
    integer(long), intent(in)  :: nelmnts 
    integer, intent(in)  :: nspec2D_xmin, nspec2D_xmax, nspec2D_ymin, nspec2D_ymax, nspec2D_bottom, nspec2D_top
    integer, dimension(nspec2D_xmin), intent(in) :: ibelm_xmin
    integer, dimension(nspec2D_xmax), intent(in) :: ibelm_xmax
    integer, dimension(nspec2D_ymin), intent(in) :: ibelm_ymin
    integer, dimension(nspec2D_ymax), intent(in) :: ibelm_ymax
    integer, dimension(nspec2D_bottom), intent(in) :: ibelm_bottom
    integer, dimension(nspec2D_top), intent(in) :: ibelm_top 

    integer, dimension(4,nspec2D_xmin), intent(in) :: nodes_ibelm_xmin
    integer, dimension(4,nspec2D_xmax), intent(in) :: nodes_ibelm_xmax
    integer, dimension(4,nspec2D_ymin), intent(in) :: nodes_ibelm_ymin
    integer, dimension(4,nspec2D_ymax), intent(in) :: nodes_ibelm_ymax
    integer, dimension(4,nspec2D_bottom), intent(in) :: nodes_ibelm_bottom
    integer, dimension(4,nspec2D_top), intent(in) :: nodes_ibelm_top    
    integer, dimension(:), pointer :: glob2loc_elmnts
    integer, dimension(:), pointer  :: glob2loc_nodes_nparts
    integer, dimension(:), pointer  :: glob2loc_nodes_parts
    integer, dimension(:), pointer  :: glob2loc_nodes
    integer, dimension(1:nelmnts)  :: part

    integer  :: i,j
    integer  :: loc_node1, loc_node2, loc_node3, loc_node4
    integer  :: loc_nspec2D_xmin,loc_nspec2D_xmax,loc_nspec2D_ymin,loc_nspec2D_ymax,loc_nspec2D_bottom,loc_nspec2D_top 
  
    
    ! counts number of elements for boundary at xmin, xmax, ymin, ymax, bottom, top in this partition
    loc_nspec2D_xmin = 0
    do i=1,nspec2D_xmin  
       if(part(ibelm_xmin(i)) == iproc) then
          loc_nspec2D_xmin = loc_nspec2D_xmin + 1
       end if
    end do
    write(IIN_database,*) 1, loc_nspec2D_xmin
    loc_nspec2D_xmax = 0
    do i=1,nspec2D_xmax  
       if(part(ibelm_xmax(i)) == iproc) then
          loc_nspec2D_xmax = loc_nspec2D_xmax + 1
       end if
    end do
    write(IIN_database,*) 2, loc_nspec2D_xmax
    loc_nspec2D_ymin = 0
    do i=1,nspec2D_ymin  
       if(part(ibelm_ymin(i)) == iproc) then
          loc_nspec2D_ymin = loc_nspec2D_ymin + 1
       end if
    end do
    write(IIN_database,*) 3, loc_nspec2D_ymin
    loc_nspec2D_ymax = 0
    do i=1,nspec2D_ymax  
       if(part(ibelm_ymax(i)) == iproc) then
          loc_nspec2D_ymax = loc_nspec2D_ymax + 1
       end if
    end do
    write(IIN_database,*) 4, loc_nspec2D_ymax
    loc_nspec2D_bottom = 0
    do i=1,nspec2D_bottom  
       if(part(ibelm_bottom(i)) == iproc) then
          loc_nspec2D_bottom = loc_nspec2D_bottom + 1
       end if
    end do
    write(IIN_database,*) 5, loc_nspec2D_bottom
    loc_nspec2D_top = 0
    do i=1,nspec2D_top  
       if(part(ibelm_top(i)) == iproc) then
          loc_nspec2D_top = loc_nspec2D_top + 1
       end if
    end do
    write(IIN_database,*) 6, loc_nspec2D_top

    ! outputs element index and element node indices
    ! note: assumes that element indices in ibelm_* arrays are in the range from 1 to nspec
    !          (this is assigned by CUBIT, if this changes the following indexing must be changed as well)
    !          while glob2loc_elmnts(.) is shifted from 0 to nspec-1  thus 
    !          we need to have the arg of glob2loc_elmnts start at 0 ==> glob2loc_nodes(ibelm_** -1 )
    do i=1,nspec2D_xmin  
       if(part(ibelm_xmin(i)) == iproc) then
          do j = glob2loc_nodes_nparts(nodes_ibelm_xmin(1,i)-1), glob2loc_nodes_nparts(nodes_ibelm_xmin(1,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node1 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_xmin(2,i)-1), glob2loc_nodes_nparts(nodes_ibelm_xmin(2,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node2 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_xmin(3,i)-1), glob2loc_nodes_nparts(nodes_ibelm_xmin(3,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node3 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_xmin(4,i)-1), glob2loc_nodes_nparts(nodes_ibelm_xmin(4,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node4 = glob2loc_nodes(j)+1
             end if
          end do
          write(IIN_database,*) glob2loc_elmnts(ibelm_xmin(i)-1)+1, loc_node1, loc_node2, loc_node3, loc_node4  
       end if
    end do

    do i=1,nspec2D_xmax     
       if(part(ibelm_xmax(i)) == iproc) then
          do j = glob2loc_nodes_nparts(nodes_ibelm_xmax(1,i)-1), glob2loc_nodes_nparts(nodes_ibelm_xmax(1,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node1 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_xmax(2,i)-1), glob2loc_nodes_nparts(nodes_ibelm_xmax(2,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node2 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_xmax(3,i)-1), glob2loc_nodes_nparts(nodes_ibelm_xmax(3,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node3 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_xmax(4,i)-1), glob2loc_nodes_nparts(nodes_ibelm_xmax(4,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node4 = glob2loc_nodes(j)+1
             end if
          end do
          write(IIN_database,*) glob2loc_elmnts(ibelm_xmax(i)-1)+1, loc_node1, loc_node2, loc_node3, loc_node4  
       end if
    end do

    do i=1,nspec2D_ymin     
       if(part(ibelm_ymin(i)) == iproc) then
          do j = glob2loc_nodes_nparts(nodes_ibelm_ymin(1,i)-1), glob2loc_nodes_nparts(nodes_ibelm_ymin(1,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node1 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_ymin(2,i)-1), glob2loc_nodes_nparts(nodes_ibelm_ymin(2,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node2 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_ymin(3,i)-1), glob2loc_nodes_nparts(nodes_ibelm_ymin(3,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node3 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_ymin(4,i)-1), glob2loc_nodes_nparts(nodes_ibelm_ymin(4,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node4 = glob2loc_nodes(j)+1
             end if
          end do
          write(IIN_database,*) glob2loc_elmnts(ibelm_ymin(i)-1)+1, loc_node1, loc_node2, loc_node3, loc_node4  
       end if
    end do
    
    do i=1,nspec2D_ymax
       if(part(ibelm_ymax(i)) == iproc) then
          do j = glob2loc_nodes_nparts(nodes_ibelm_ymax(1,i)-1), glob2loc_nodes_nparts(nodes_ibelm_ymax(1,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node1 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_ymax(2,i)-1), glob2loc_nodes_nparts(nodes_ibelm_ymax(2,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node2 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_ymax(3,i)-1), glob2loc_nodes_nparts(nodes_ibelm_ymax(3,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node3 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_ymax(4,i)-1), glob2loc_nodes_nparts(nodes_ibelm_ymax(4,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node4 = glob2loc_nodes(j)+1
             end if
          end do
          write(IIN_database,*) glob2loc_elmnts(ibelm_ymax(i)-1)+1, loc_node1, loc_node2, loc_node3, loc_node4  
       end if
    end do

    do i=1,nspec2D_bottom
       if(part(ibelm_bottom(i)) == iproc) then
          do j = glob2loc_nodes_nparts(nodes_ibelm_bottom(1,i)-1), glob2loc_nodes_nparts(nodes_ibelm_bottom(1,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node1 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_bottom(2,i)-1), glob2loc_nodes_nparts(nodes_ibelm_bottom(2,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node2 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_bottom(3,i)-1), glob2loc_nodes_nparts(nodes_ibelm_bottom(3,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node3 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_bottom(4,i)-1), glob2loc_nodes_nparts(nodes_ibelm_bottom(4,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node4 = glob2loc_nodes(j)+1
             end if
          end do
          write(IIN_database,*) glob2loc_elmnts(ibelm_bottom(i)-1)+1, loc_node1, loc_node2, loc_node3, loc_node4  
       end if
    end do

    do i=1,nspec2D_top    
       if(part(ibelm_top(i)) == iproc) then
          do j = glob2loc_nodes_nparts(nodes_ibelm_top(1,i)-1), glob2loc_nodes_nparts(nodes_ibelm_top(1,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node1 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_top(2,i)-1), glob2loc_nodes_nparts(nodes_ibelm_top(2,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node2 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_top(3,i)-1), glob2loc_nodes_nparts(nodes_ibelm_top(3,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node3 = glob2loc_nodes(j)+1
             end if
          end do
          do j = glob2loc_nodes_nparts(nodes_ibelm_top(4,i)-1), glob2loc_nodes_nparts(nodes_ibelm_top(4,i))-1
             if (glob2loc_nodes_parts(j) == iproc ) then
                loc_node4 = glob2loc_nodes(j)+1
             end if
          end do
          write(IIN_database,*) glob2loc_elmnts(ibelm_top(i)-1)+1, loc_node1, loc_node2, loc_node3, loc_node4  
       end if

    end do


  end subroutine write_boundaries_database


  !--------------------------------------------------
  ! Write elements (their nodes) pertaining to iproc partition in the corresponding Database
  !--------------------------------------------------
  subroutine write_partition_database(IIN_database, iproc, nspec, nelmnts, elmnts, glob2loc_elmnts, glob2loc_nodes_nparts, &
     glob2loc_nodes_parts, glob2loc_nodes, part, num_modele, ngnod, num_phase)

    include './constants_decompose_mesh_SCOTCH.h'

    integer, intent(in)  :: IIN_database
    integer, intent(in)  :: num_phase, iproc
    integer(long), intent(in)  :: nelmnts
    integer, intent(inout)  :: nspec
    integer, dimension(0:nelmnts-1)  :: part
    integer, dimension(0:esize*nelmnts-1)  :: elmnts
    integer, dimension(:), pointer :: glob2loc_elmnts
    integer, dimension(2,nspec)  :: num_modele
    integer, dimension(:), pointer  :: glob2loc_nodes_nparts
    integer, dimension(:), pointer  :: glob2loc_nodes_parts
    integer, dimension(:), pointer  :: glob2loc_nodes
    integer, intent(in)  :: ngnod

    integer  :: i,j,k
    integer, dimension(0:ngnod-1)  :: loc_nodes

    if ( num_phase == 1 ) then
       nspec = 0

       do i = 0, nelmnts-1
          if ( part(i) == iproc ) then
             nspec = nspec + 1

          end if
       end do

    else
       do i = 0, nelmnts-1
          if ( part(i) == iproc ) then

             do j = 0, ngnod-1
                do k = glob2loc_nodes_nparts(elmnts(i*ngnod+j)), glob2loc_nodes_nparts(elmnts(i*ngnod+j)+1)-1

                   if ( glob2loc_nodes_parts(k) == iproc ) then
                      loc_nodes(j) = glob2loc_nodes(k)

                   end if
                end do

             end do
             write(IIN_database,*) glob2loc_elmnts(i)+1, num_modele(1,i+1), num_modele(2,i+1),(loc_nodes(k)+1, k=0,ngnod-1)
          end if
       end do
    end if


  end subroutine write_partition_database



  !--------------------------------------------------
  ! Write interfaces (element and common nodes) pertaining to iproc partition in the corresponding Database
  !--------------------------------------------------
  subroutine write_interfaces_database(IIN_database, tab_interfaces, tab_size_interfaces, iproc, ninterfaces, &
       my_ninterface, my_interfaces, my_nb_interfaces, glob2loc_elmnts, glob2loc_nodes_nparts, glob2loc_nodes_parts, &
       glob2loc_nodes, num_phase)

    include './constants_decompose_mesh_SCOTCH.h'

    integer, intent(in)  :: IIN_database
    integer, intent(in)  :: iproc
    integer, intent(in)  :: ninterfaces
    integer, intent(inout)  :: my_ninterface
    integer, dimension(:), pointer  :: tab_size_interfaces
    integer, dimension(:), pointer  :: tab_interfaces
    integer, dimension(0:ninterfaces-1), intent(inout)  :: my_interfaces
    integer, dimension(0:ninterfaces-1), intent(inout)  :: my_nb_interfaces
    integer, dimension(:), pointer  :: glob2loc_elmnts
    integer, dimension(:), pointer  :: glob2loc_nodes_nparts
    integer, dimension(:), pointer  :: glob2loc_nodes_parts
    integer, dimension(:), pointer  :: glob2loc_nodes

    integer, dimension(4)  :: local_nodes
    integer  :: local_elmnt
    integer  :: num_phase

    integer  :: i, j, k, l
    integer  :: num_interface

    num_interface = 0

    if ( num_phase == 1 ) then

       my_interfaces(:) = 0
       my_nb_interfaces(:) = 0

       do i = 0, nparts-1
          do j = i+1, nparts-1
             if ( (tab_size_interfaces(num_interface) < tab_size_interfaces(num_interface+1)) .and. &
                  (i == iproc .or. j == iproc) ) then
                my_interfaces(num_interface) = 1
                my_nb_interfaces(num_interface) = tab_size_interfaces(num_interface+1) - tab_size_interfaces(num_interface)
             end if
             num_interface = num_interface + 1
          end do
       end do
       my_ninterface = sum(my_interfaces(:))

    else

      do i = 0, nparts-1
         do j = i+1, nparts-1
            if ( my_interfaces(num_interface) == 1 ) then
               if ( i == iproc ) then
                  write(IIN_database,*) j, my_nb_interfaces(num_interface)
               else
                  write(IIN_database,*) i, my_nb_interfaces(num_interface)
               end if

               do k = tab_size_interfaces(num_interface), tab_size_interfaces(num_interface+1)-1
                  if ( i == iproc ) then
                     local_elmnt = glob2loc_elmnts(tab_interfaces(k*7+0))+1
                  else
                     local_elmnt = glob2loc_elmnts(tab_interfaces(k*7+1))+1
                  end if

!!$                  if ( tab_interfaces(k*7+2) == 1 ) then
!!$                     do l = glob2loc_nodes_nparts(tab_interfaces(k*7+3)), &
!!$                          glob2loc_nodes_nparts(tab_interfaces(k*7+3)+1)-1
!!$                        if ( glob2loc_nodes_parts(l) == iproc ) then
!!$                           local_nodes(1) = glob2loc_nodes(l)+1
!!$                        end if
!!$                     end do
!!$
!!$                     write(IIN_database,*) local_elmnt, tab_interfaces(k*7+2), local_nodes(1), -1
!!$                  else
!!$                     if ( tab_interfaces(k*7+2) == 2 ) then
!!$                        do l = glob2loc_nodes_nparts(tab_interfaces(k*7+3)), &
!!$                             glob2loc_nodes_nparts(tab_interfaces(k*7+3)+1)-1
!!$                           if ( glob2loc_nodes_parts(l) == iproc ) then
!!$                              local_nodes(1) = glob2loc_nodes(l)+1
!!$                           end if
!!$                        end do
!!$                        do l = glob2loc_nodes_nparts(tab_interfaces(k*7+4)), &
!!$                           glob2loc_nodes_nparts(tab_interfaces(k*7+4)+1)-1
!!$                           if ( glob2loc_nodes_parts(l) == iproc ) then
!!$                              local_nodes(2) = glob2loc_nodes(l)+1
!!$                           end if
!!$                        end do
!!$                        write(IIN_database,*) local_elmnt, tab_interfaces(k*7+2), local_nodes(1), local_nodes(2)
!!$                     else
!!$                        write(IIN_database,*) "erreur_write_interface_", tab_interfaces(k*7+2)
!!$                     end if
!!$                  end if
                  select case (tab_interfaces(k*7+2))
                  case (1)
                     do l = glob2loc_nodes_nparts(tab_interfaces(k*7+3)), &
                          glob2loc_nodes_nparts(tab_interfaces(k*7+3)+1)-1
                        if ( glob2loc_nodes_parts(l) == iproc ) then
                           local_nodes(1) = glob2loc_nodes(l)+1
                        end if
                     end do
                     write(IIN_database,*) local_elmnt, tab_interfaces(k*7+2), local_nodes(1), -1, -1, -1
                  case (2)
                     do l = glob2loc_nodes_nparts(tab_interfaces(k*7+3)), &
                          glob2loc_nodes_nparts(tab_interfaces(k*7+3)+1)-1
                        if ( glob2loc_nodes_parts(l) == iproc ) then
                           local_nodes(1) = glob2loc_nodes(l)+1
                        end if
                     end do
                     do l = glob2loc_nodes_nparts(tab_interfaces(k*7+4)), &
                          glob2loc_nodes_nparts(tab_interfaces(k*7+4)+1)-1
                        if ( glob2loc_nodes_parts(l) == iproc ) then
                           local_nodes(2) = glob2loc_nodes(l)+1
                        end if
                     end do
                     write(IIN_database,*) local_elmnt, tab_interfaces(k*7+2), local_nodes(1), local_nodes(2), -1, -1
                  case (4)
                     do l = glob2loc_nodes_nparts(tab_interfaces(k*7+3)), &
                          glob2loc_nodes_nparts(tab_interfaces(k*7+3)+1)-1
                        if ( glob2loc_nodes_parts(l) == iproc ) then
                           local_nodes(1) = glob2loc_nodes(l)+1
                        end if
                     end do
                     do l = glob2loc_nodes_nparts(tab_interfaces(k*7+4)), &
                          glob2loc_nodes_nparts(tab_interfaces(k*7+4)+1)-1
                        if ( glob2loc_nodes_parts(l) == iproc ) then
                           local_nodes(2) = glob2loc_nodes(l)+1
                        end if
                     end do
                     do l = glob2loc_nodes_nparts(tab_interfaces(k*7+5)), &
                          glob2loc_nodes_nparts(tab_interfaces(k*7+5)+1)-1
                        if ( glob2loc_nodes_parts(l) == iproc ) then
                           local_nodes(3) = glob2loc_nodes(l)+1
                        end if
                     end do
                     do l = glob2loc_nodes_nparts(tab_interfaces(k*7+6)), &
                          glob2loc_nodes_nparts(tab_interfaces(k*7+6)+1)-1
                        if ( glob2loc_nodes_parts(l) == iproc ) then
                           local_nodes(4) = glob2loc_nodes(l)+1
                        end if
                     end do
                     write(IIN_database,*) local_elmnt, tab_interfaces(k*7+2), &
                          local_nodes(1), local_nodes(2),local_nodes(3), local_nodes(4)
                  case default
                     print *, "error in write_interfaces_database!", tab_interfaces(k*7+2), iproc
                  end select
               end do

            end if

            num_interface = num_interface + 1
         end do
      end do

   end if

 end subroutine write_interfaces_database

end module part_decompose_mesh_SCOTCH
