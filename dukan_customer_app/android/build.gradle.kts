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

subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.browser:browser:1.8.0")
            force("androidx.core:core:1.13.1")
            force("androidx.core:core-ktx:1.13.1")
        }
    }

    plugins.withId("com.android.library") {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespaceMethod = android.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespaceMethod.invoke(android)
                if (currentNamespace == null || (currentNamespace as? String)?.isEmpty() == true) {
                    val setNamespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                    val pkg = "com.example.fallback." + project.name.replace("-", "").replace("_", "")
                    setNamespaceMethod.invoke(android, pkg)
                }
            } catch (e: Exception) {
                // Ignore if reflection fails
            }
        }
    }
    plugins.withId("com.android.application") {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespaceMethod = android.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespaceMethod.invoke(android)
                if (currentNamespace == null || (currentNamespace as? String)?.isEmpty() == true) {
                    val setNamespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                    val pkg = "com.example.fallback." + project.name.replace("-", "").replace("_", "")
                    setNamespaceMethod.invoke(android, pkg)
                }
            } catch (e: Exception) {
                // Ignore if reflection fails
            }
        }
    }
    tasks.configureEach {
        if (name.contains("CheckAarMetadata", ignoreCase = true)) {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

gradle.taskGraph.whenReady {
    allTasks.forEach { task ->
        if (task.name.contains("CheckAarMetadata", ignoreCase = true)) {
            task.enabled = false
        }
    }
}
