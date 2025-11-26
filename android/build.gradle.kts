// Top-level build file where you can add configuration options common to all sub-projects/modules.

// Define repositories for all projects (common dependencies sources)
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Custom configuration to redirect the build output directory
// This is typically used in multi-module projects or specific build environments.
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build") // Redirects build artifacts to a higher-level 'build' directory
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Apply the new build directory configuration to all subprojects
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Ensures subprojects depend on the :app module for proper configuration during evaluation
subprojects {
    project.evaluationDependsOn(":app")
}

// Define a 'clean' task to delete the generated build directory
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
