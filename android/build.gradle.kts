allprojects {
    repositories {
        google()
        mavenCentral()
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

subprojects {
    val configureNamespace = { proj: Project ->
        if (proj.name == "tdlib") {
            val android = proj.extensions.findByName("android")
            if (android != null) {
                try {
                    val setNamespace = android.javaClass.methods.firstOrNull { it.name == "setNamespace" }
                    if (setNamespace != null) {
                        setNamespace.invoke(android, "org.naji.td.tdlib")
                        println("Successfully injected namespace 'org.naji.td.tdlib' for :tdlib module")
                    } else {
                        println("setNamespace method not found on android extension")
                    }

                    // Dynamically set compileSdkVersion to 34 to satisfy AndroidX AAR check constraints
                    val compileSdkMethod = android.javaClass.methods.firstOrNull { 
                        it.name == "compileSdkVersion" && it.parameterTypes.isNotEmpty() && it.parameterTypes[0] == Int::class.javaPrimitiveType
                    } ?: android.javaClass.methods.firstOrNull { 
                        it.name == "compileSdkVersion" && it.parameterTypes.isNotEmpty() && it.parameterTypes[0] == java.lang.Integer::class.java
                    } ?: android.javaClass.methods.firstOrNull { 
                        it.name == "setCompileSdk"
                    }
                    if (compileSdkMethod != null) {
                        compileSdkMethod.invoke(android, 34)
                        println("Successfully injected compileSdk 34 for :tdlib module")
                    }
                } catch (e: Exception) {
                    println("Failed to inject configurations for tdlib: $e")
                }
            }
        }
    }

    if (project.state.executed) {
        configureNamespace(project)
    } else {
        project.afterEvaluate {
            configureNamespace(project)
        }
    }
}
