package com.spring.tourism.Controller;

import com.spring.tourism.Support.MailService;
import com.spring.tourism.Support.SendMessage;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

import javax.servlet.http.HttpServletResponse;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Controller
@RequestMapping("/verifyCode")
public class VerifyCodeController {
    private static final String basicPhoneUrl =
            "http://www.qunfaduanxin.vip/api/send?username=1900327840&password=E10ADC3949BA59ABBE56E057F20F883E" +
                    "&gwid=oookc081&mobile=%s&message=【IM及时通讯】您的IM稳定版的验证码是：%s，如非本人操作请忽略";
    private static final String basicMailText = "【tourism】 您的验证码：%s";

    private final MailService mailService;

    public VerifyCodeController(MailService mailService) {
        this.mailService = mailService;
    }

    @GetMapping(path = "/mailCode")
    public void getMailCode(String mailAddress,
                            HttpServletResponse response) {
        int randomNum = (int) (Math.random() * 1e6);
        try {
            mailService.sendSimpleMessage(mailAddress, "【验证码】",
                    String.format("【IM及时通讯】您的IM稳定版的验证码是：%s，如非本人操作请忽略", randomNum));
            response.getWriter().write(String.valueOf(randomNum));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @GetMapping(path = "/phoneCode")
    public void getPhoneCode(String phone,
                             HttpServletResponse response) {
        int[] random = new int[6];
        for (int i = 0; i < random.length; ++i) {
            random[i] = (int) (Math.random() * 10);
        }
        int randomNum = 0;
        for (int value : random) {
            randomNum += randomNum * 10 + value;
        }
        try {
            SendMessage sendMessage = new SendMessage();
            String result = sendMessage.sendMessage(String.format(basicPhoneUrl, phone,randomNum));
            if (result != null) {
                // 使用正则表达式匹配发送短信的结果
                Pattern regexSuccess = Pattern.compile("(?i)success");
                Matcher matcher = regexSuccess.matcher(result);
                if (matcher.find()) {
                    response.getWriter().write(String.valueOf(randomNum));
                } else {
                    response.getWriter().write("404");
                }
            } else {
                response.getWriter().write("400");
            }
        } catch (Exception e) {
           e.printStackTrace();
        }
    }
}
