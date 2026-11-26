package com.example.app;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.library.GeneralCodingRules;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.*;

/** Deterministic architecture guardrails (see the architecture-guardrails skill). */
class ArchitectureTest {

    private static final JavaClasses CLASSES = new ClassFileImporter().importPackages("com.example.app");

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
}
