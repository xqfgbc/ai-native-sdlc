package com.example.app;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;

import java.nio.file.Paths;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Executors;
import com.tngtech.archunit.library.GeneralCodingRules;
import jakarta.persistence.Entity;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestClient;

import static com.tngtech.archunit.core.domain.JavaCall.Predicates.target;
import static com.tngtech.archunit.core.domain.JavaClass.Predicates.equivalentTo;
import static com.tngtech.archunit.core.domain.properties.HasName.Predicates.nameMatching;
import static com.tngtech.archunit.core.domain.properties.HasOwner.Predicates.With.owner;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.methods;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

/** Deterministic architecture guardrails (see the architecture-guardrails skill). */
class ArchitectureTest {

    // Import production classes only: test classes legitimately use field injection.
    private static final JavaClasses CLASSES = new ClassFileImporter()
            .importPath(Paths.get("build/classes/java/main"));

    @Test
    void controllersLiveInApi() {
        classes().that().areAnnotatedWith(org.springframework.web.bind.annotation.RestController.class)
                .should().resideInAPackage("com.example.app.api..")
                .allowEmptyShould(true)
                .check(CLASSES);
    }

    @Test
    void coreMustNotDependOnWeb() {
        noClasses().that().resideInAPackage("com.example.app.core..")
                .should().dependOnClassesThat().resideInAnyPackage(
                        "com.example.app.api..",
                        "org.springframework.web..",
                        "org.springframework.http..",
                        "jakarta.servlet..")
                .allowEmptyShould(true)
                .check(CLASSES);
    }

    @Test
    void noFieldInjection() {
        GeneralCodingRules.NO_CLASSES_SHOULD_USE_FIELD_INJECTION.check(CLASSES);
    }

    @Test
    void noLegacyDate() {
        noClasses().should().dependOnClassesThat().haveFullyQualifiedName("java.util.Date")
                .allowEmptyShould(true)
                .check(CLASSES);
    }

    @Test
    void entitiesLiveInThePersistenceAdapter() {
        classes().that().areAnnotatedWith(Entity.class)
                .should().resideInAPackage("com.example.app.adapters.persistence..")
                .allowEmptyShould(true)
                .check(CLASSES);
    }

    @Test
    void apiMustNotDependOnAdapters() {
        noClasses().that().resideInAPackage("com.example.app.api..")
                .should().dependOnClassesThat().resideInAPackage("com.example.app.adapters..")
                .allowEmptyShould(true)
                .check(CLASSES);
    }

    @Test
    void noRawThreadPools() {
        noClasses().should().callMethodWhere(target(owner(equivalentTo(Executors.class))))
                .allowEmptyShould(true)
                .check(CLASSES);
    }

    @Test
    void noRawThreads() {
        noClasses().should().callConstructorWhere(target(owner(equivalentTo(Thread.class))))
                .allowEmptyShould(true)
                .check(CLASSES);
    }

    @Test
    void noUnmanagedCompletableFuture() {
        noClasses().should().callMethodWhere(
                        target(owner(equivalentTo(CompletableFuture.class)))
                                .and(nameMatching("(supplyAsync|runAsync)")))
                .allowEmptyShould(true)
                .check(CLASSES);
    }

    @Test
    void noHandBuiltRestClient() {
        noClasses().should().callMethodWhere(
                        target(owner(equivalentTo(RestClient.class))).and(nameMatching("(create|builder)")))
                .allowEmptyShould(true)
                .check(CLASSES);
    }

    @Test
    void transactionalMethodsArePublic() {
        methods().that().areAnnotatedWith(Transactional.class)
                .should().bePublic()
                .allowEmptyShould(true)
                .check(CLASSES);
    }
}
