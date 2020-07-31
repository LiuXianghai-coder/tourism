package com.spring.tourism.Support;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Component;
import org.thymeleaf.context.Context;
import org.thymeleaf.spring5.SpringTemplateEngine;

import javax.mail.MessagingException;
import javax.mail.internet.MimeMessage;
import java.io.File;
import java.io.IOException;
import java.util.Map;

@Component
public class MailServiceImpl implements MailService {
    private static final String NOREPLY_ADDRESS = "GuiHuaLinked@163.com";

    private final JavaMailSender javaMailSender;

    private final SpringTemplateEngine springTemplateEngine;

    public MailServiceImpl(JavaMailSender javaMailSender,
                           SpringTemplateEngine springTemplateEngine) {
        this.javaMailSender = javaMailSender;
        this.springTemplateEngine = springTemplateEngine;
    }

    @Value("classpath:/mail-logo.png")
    private Resource resourceFile;

    @Override
    public void sendSimpleMessage(String to,
                                  String subject,
                                  String text) {
        try {
            SimpleMailMessage simpleMailMessage = new SimpleMailMessage();
            simpleMailMessage.setFrom(NOREPLY_ADDRESS);
            simpleMailMessage.setSubject(subject);
            simpleMailMessage.setTo(to);
            simpleMailMessage.setText(text);

            javaMailSender.send(simpleMailMessage);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }


    @Override
    public void sendMessageWithAttachment(String to,
                                          String subject,
                                          String text,
                                          String pathToAttachment) {
        try {
            MimeMessage message = javaMailSender.createMimeMessage();
            // pass 'true' to the constructor to create a multipart message
            MimeMessageHelper helper = new MimeMessageHelper(message, true);

            helper.setFrom(NOREPLY_ADDRESS);
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(text);

            FileSystemResource file = new FileSystemResource(new File(pathToAttachment));
            helper.addAttachment("Invoice", file);

            javaMailSender.send(message);
        } catch (MessagingException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void sendMessageUsingThymeleafTemplate(String to,
                                                  String subject,
                                                  Map<String, Object> templateModel)
            throws IOException, MessagingException {
        Context thymeleafContext = new Context();
        thymeleafContext.setVariables(templateModel);

        String htmlBody = springTemplateEngine.
                process("template-thymeleaf.html", thymeleafContext);

        sendHtmlMessage(to, subject, htmlBody);
    }


    private void sendHtmlMessage(String to,
                                 String subject,
                                 String htmlBody)
            throws MessagingException {
        MimeMessage message = javaMailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
        helper.setFrom(NOREPLY_ADDRESS);
        helper.setTo(to);
        helper.setSubject(subject);
        helper.setText(htmlBody, true);
        helper.addInline("attachment.png", resourceFile);
        javaMailSender.send(message);
    }
}
