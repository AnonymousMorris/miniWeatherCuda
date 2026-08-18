find_program(UV_EXECUTABLE uv REQUIRED)

set(REFERENCE_NX 100)
set(REFERENCE_NZ 50)
set(REFERENCE_SIM_TIME 20)
set(REFERENCE_OUTPUT_FREQ 20)
set(REFERENCE_SOURCE "${CMAKE_CURRENT_LIST_DIR}/../miniWeather_mpi_cuda.cu")
set(REFERENCE_SCRIPT "${CMAKE_CURRENT_LIST_DIR}/compare.py")
set(REFERENCE_DATA "${CMAKE_CURRENT_LIST_DIR}/references.json")

function(link_miniweather_dependencies target)
  if(NOT "${LDFLAGS}" STREQUAL "")
    target_link_libraries(${target} PRIVATE "${LDFLAGS}")
  endif()
  if(NOT "${MPI_LINK_FLAGS}" STREQUAL "")
    target_link_libraries(${target} PRIVATE "${MPI_LINK_FLAGS}")
  endif()
  target_link_libraries(${target} PRIVATE "${CUDA_LINK_FLAGS}" Threads::Threads)
endfunction()

function(add_cuda_reference_test case_name data_spec)
  set(target "cuda_reference_${case_name}")
  add_executable(${target} "${REFERENCE_SOURCE}")
  target_compile_definitions(${target} PRIVATE
    _NX=${REFERENCE_NX}
    _NZ=${REFERENCE_NZ}
    _SIM_TIME=${REFERENCE_SIM_TIME}
    _OUT_FREQ=${REFERENCE_OUTPUT_FREQ}
    _DATA_SPEC=${data_spec}
    NO_INFORM)
  target_compile_options(${target} PRIVATE -O3)
  set_target_properties(${target} PROPERTIES CUDA_ARCHITECTURES "80")
  link_miniweather_dependencies(${target})

  string(TOUPPER "${case_name}" upper_case_name)
  add_test(
    NAME CUDA_REFERENCE_${upper_case_name}
    COMMAND
      "${UV_EXECUTABLE}"
      run
      --script
      "${REFERENCE_SCRIPT}"
      "${case_name}"
      "$<TARGET_FILE:${target}>"
      "${REFERENCE_DATA}")
endfunction()

add_cuda_reference_test(collision DATA_SPEC_COLLISION)
add_cuda_reference_test(thermal DATA_SPEC_THERMAL)
add_cuda_reference_test(density_current DATA_SPEC_DENSITY_CURRENT)
add_cuda_reference_test(injection DATA_SPEC_INJECTION)
