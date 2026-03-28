package ca.uhn.fhir.jpa.starter.web;

import ca.uhn.fhir.jpa.starter.AppProperties;
import org.jetbrains.annotations.NotNull;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
@ConditionalOnProperty(prefix = "hapi.fhir", name = "custom_content_path")
public class CustomContentFilesConfigurer implements WebMvcConfigurer {

	public static final String CUSTOM_CONTENT = "/content";
	private String customContentPath;

	public CustomContentFilesConfigurer(AppProperties appProperties) {
		customContentPath = appProperties.getCustom_content_path();
	}

	@Override
	public void addResourceHandlers(@NotNull ResourceHandlerRegistry theRegistry) {
		if (!theRegistry.hasMappingForPattern(CUSTOM_CONTENT + "/**")) {
			String path = customContentPath;
			if (!path.endsWith("/")) {
				path = path + "/";
			}
			// Ensure proper file:// URL format for absolute paths
			if (path.startsWith("/")) {
				path = "file://" + path;
			}
			theRegistry
					.addResourceHandler(CUSTOM_CONTENT + "/**")
					.addResourceLocations(path);
		}
	}
}
