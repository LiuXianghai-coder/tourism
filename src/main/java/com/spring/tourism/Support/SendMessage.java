package com.spring.tourism.Support;

import org.jsoup.Connection;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;

public class SendMessage {
    public String sendMessage(String url) {
        if (url == null || url.trim().length() == 0) {
            throw new IllegalArgumentException("URL error");
        }

        try {
            Connection connection = Jsoup.connect(url);
            Document document = connection.get();
//            System.out.println(document.toString());
            return document.toString();
        } catch (Exception e) {
            System.out.println("Get URL error.");
            return null;
        }
    }
}
