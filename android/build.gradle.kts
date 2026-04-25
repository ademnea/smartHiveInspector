allprojects {
    repositories {
        google()
        mavenCentral()
        jcenter()
        
        // Add this repository
        maven { url = uri("https://jitpack.io") }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (name == "ffmpeg_kit_flutter_android") {
        // Work around ffmpeg_kit_flutter_android 1.4.0 dynamic dependency timing.
        // Adding dependency at configuration time makes FFmpeg classes visible to javac.
        pluginManager.withPlugin("com.android.library") {
            dependencies {
                add(
                    "implementation",
                    "com.arthenica.ffmpegkit:flutter:6.0",
                )
            }
        }

        tasks.matching { it.name == "preBuild" }.configureEach {
            dependsOn("setupDependencies")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
