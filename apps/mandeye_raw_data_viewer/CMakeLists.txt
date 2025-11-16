cmake_minimum_required(VERSION 4.0.0)

project(mandeye_raw_data_viewer)

add_executable(
  mandeye_raw_data_viewer
  mandeye_raw_data_viewer.cpp
  ../lidar_odometry_step_1/lidar_odometry_utils.cpp
  ../lidar_odometry_step_1/lidar_odometry_gui_utils.cpp
  ../lidar_odometry_step_1/lidar_odometry_utils_optimizers.cpp
)

target_include_directories(
  mandeye_raw_data_viewer
  PRIVATE include
  ${REPOSITORY_DIRECTORY}/core/include
  ${REPOSITORY_DIRECTORY}/core_hd_mapping/include
  ${EXTERNAL_LIBRARIES_DIRECTORY}
  ${EXTERNAL_LIBRARIES_DIRECTORY}/glm
  ${EIGEN3_INCLUDE_DIR}
  ${EXTERNAL_LIBRARIES_DIRECTORY}/imgui
  ${EXTERNAL_LIBRARIES_DIRECTORY}/imgui/backends
  ${EXTERNAL_LIBRARIES_DIRECTORY}/ImGuizmo
  ${EXTERNAL_LIBRARIES_DIRECTORY}/glew-2.2.0/include
  ${GLFW_INCLUDE_DIR}
  ${EXTERNAL_LIBRARIES_DIRECTORY}/json/include
  ${EXTERNAL_LIBRARIES_DIRECTORY}/portable-file-dialogs-master
  ${LASZIP_INCLUDE_DIR}/LASzip/include
  ${EXTERNAL_LIBRARIES_DIRECTORY}/observation_equations/codes
  ${EXTERNAL_LIBRARIES_DIRECTORY}/Fusion/Fusion)

target_link_libraries(
  mandeye_raw_data_viewer
  PRIVATE Fusion
  ${GLFW_LIBRARY}
  ${OPENGL_gl_LIBRARY}
  OpenGL::GLU
  ${PLATFORM_LASZIP_LIB}
  ${CORE_LIBRARIES}
  ${GUI_LIBRARIES}
  ${PLATFORM_MISCELLANEOUS_LIBS}
  ${OpenCV_LIBS})

# Link GLEW library on Windows
if(WIN32)
  target_link_libraries(
    mandeye_raw_data_viewer
    PRIVATE ${EXTERNAL_LIBRARIES_DIRECTORY}/glew-2.2.0/lib/Release/x64/glew32.lib)
endif()

if(WIN32)
  add_custom_command(
    TARGET mandeye_raw_data_viewer
    POST_BUILD
    COMMAND
    ${CMAKE_COMMAND} -E copy $<TARGET_RUNTIME_DLLS:mandeye_raw_data_viewer>
    $<TARGET_FILE_DIR:mandeye_raw_data_viewer>
    COMMAND
    ${CMAKE_COMMAND} -E copy_if_different
    ${EXTERNAL_LIBRARIES_DIRECTORY}/glew-2.2.0/bin/Release/x64/glew32.dll
    $<TARGET_FILE_DIR:mandeye_raw_data_viewer>
    COMMAND_EXPAND_LISTS)
endif()

if (MSVC)
    target_compile_options(mandeye_raw_data_viewer PRIVATE /bigobj)
endif()

install(TARGETS mandeye_raw_data_viewer DESTINATION bin)