allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // livekit_client 2.3.x pulls com.github.paramsen:noise, whose libnoise.so is
    // 4 KB-aligned and fails Play's 16 KB page-size check. io.livekit:noise is
    // LiveKit's drop-in rebuild (same com.paramsen.noise classes) with 16 KB alignment.
    configurations.all {
        resolutionStrategy.dependencySubstitution {
            substitute(module("com.github.paramsen:noise"))
                .using(module("io.livekit:noise:2.0.0"))
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}