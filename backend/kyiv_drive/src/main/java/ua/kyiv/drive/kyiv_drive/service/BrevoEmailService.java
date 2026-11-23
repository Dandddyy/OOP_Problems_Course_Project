package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.MessageSource;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import ua.kyiv.drive.kyiv_drive.exception.OperationTimeoutException;

import java.util.List;
import java.util.Locale;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class BrevoEmailService {

    @Value("${brevo.api.key}")
    private String apiKey;

    @Value("${brevo.sender.email}")
    private String senderEmail;

    @Value("${brevo.sender.name}")
    private String senderName;

    private final RestTemplate restTemplate;
    private final MessageSource messageSource;
    private final String BREVO_API_URL = "https://api.brevo.com/v3/smtp/email";

    private String getMessage(String code, Locale locale) {
        return messageSource.getMessage(code, null, locale);
    }

    public void sendOtpCode(String toEmail, String otpCode, Locale locale) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("api-key", apiKey);
        headers.set("accept", "application/json");

        String subject = getMessage("email.otp.subject", locale);

        String htmlContent = buildOtpEmailHtml(otpCode, locale);

        Map<String, Object> body = Map.of(
                "sender", Map.of("name", senderName, "email", senderEmail),
                "to", List.of(Map.of("email", toEmail)),
                "subject", subject,
                "htmlContent", htmlContent
        );

        HttpEntity<Map<String, Object>> request = new HttpEntity<>(body, headers);

        try {
            ResponseEntity<String> response = restTemplate.postForEntity(BREVO_API_URL, request, String.class);
            log.info("Email sent. Status: {}", response.getStatusCode());
        } catch (Exception e) {
            OperationTimeoutException.rethrowIfTimeout(e);
            log.error("Error sending email: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to send email", e);
        }
    }

    private String buildOtpEmailHtml(String otpCode, Locale locale) {
        String subject = getMessage("email.otp.subject", locale);
        String title = getMessage("email.otp.title", locale);
        String instruction = getMessage("email.otp.instruction", locale);
        String warning = getMessage("email.otp.warning", locale);
        String footer = getMessage("email.otp.footer", locale);
        String lang = locale.getLanguage();

        String template = """
            <!DOCTYPE html>
            <html lang="{{lang}}">
            <head>
              <meta charset="UTF-8" />
              <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
              <title>{{subject}}</title>
            </head>
            <body style="margin:0; padding:0; background-color:#f5f5f5; font-family:'Helvetica Neue', Helvetica, Arial, sans-serif;">
            
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f5f5f5; padding: 48px 16px;">
                <tr>
                  <td align="center">
                    <table width="480" cellpadding="0" cellspacing="0" style="background-color:#ffffff; border-radius:12px; overflow:hidden;">
                      
                      <tr>
                        <td style="background: linear-gradient(90deg, #00838f 0%, #bf360c 100%); height:4px; font-size:0; line-height:0;">&nbsp;</td>
                      </tr>
            
                      <tr>
                        <td align="center" style="padding: 40px 40px 0 40px;">
                          <p style="margin:0; font-size:22px; font-weight:700; letter-spacing:2px; color:#1a1a1a;">
                            KYIV<span style="color:#00838f;">DRIVE</span>
                          </p>
                        </td>
                      </tr>
            
                      <tr>
                        <td align="center" style="padding: 20px 40px 0 40px;">
                          <hr style="border:none; border-top:1px solid #eeeeee; margin:0;" />
                        </td>
                      </tr>
            
                      <tr>
                        <td align="center" style="padding: 32px 40px 8px 40px;">
                          <p style="margin:0; font-size:13px; text-transform:uppercase; letter-spacing:3px; color:#9e9e9e; font-weight:500;">
                            {{title}}
                          </p>
                        </td>
                      </tr>
            
                      <tr>
                        <td align="center" style="padding: 12px 40px 32px 40px;">
                          <div style="display:inline-block; background-color:#f9f9f9; border:1px solid #eeeeee; border-radius:10px; padding: 20px 48px;">
                            <p style="margin:0; padding-left:14px; text-align:center; font-size:42px; font-weight:700; letter-spacing:14px; color:#00838f; font-variant-numeric: tabular-nums;">
                              {{otpCode}}
                            </p>
                          </div>
                        </td>
                      </tr>
            
                      <tr>
                        <td align="center" style="padding: 0 40px 16px 40px;">
                          <p style="margin:0; font-size:14px; color:#616161; line-height:1.6;">
                            {{instruction}}
                          </p>
                        </td>
                      </tr>
            
                      <tr>
                        <td align="center" style="padding: 0 40px 40px 40px;">
                          <p style="margin:0; font-size:12px; color:#bdbdbd; line-height:1.5;">
                            {{warning}}
                          </p>
                        </td>
                      </tr>
            
                      <tr>
                        <td align="center" style="background-color:#fafafa; border-top:1px solid #eeeeee; padding: 20px 40px;">
                          <p style="margin:0; font-size:11px; color:#bdbdbd; letter-spacing:1px;">
                            {{footer}}
                          </p>
                        </td>
                      </tr>
            
                    </table>
                  </td>
                </tr>
              </table>
            
            </body>
            </html>
            """;

        return template
                .replace("{{lang}}", lang)
                .replace("{{subject}}", subject)
                .replace("{{title}}", title)
                .replace("{{otpCode}}", otpCode)
                .replace("{{instruction}}", instruction)
                .replace("{{warning}}", warning)
                .replace("{{footer}}", footer);
    }
}
