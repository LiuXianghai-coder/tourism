package com.spring.tourism.Support;

import java.math.BigInteger;
import java.security.MessageDigest;

public class SHA512 {
    public String encryptThisString(String input) {
        try {
            MessageDigest messageDigest = MessageDigest.getInstance("SHA-512");

            byte[] md = messageDigest.digest(input.getBytes());

            BigInteger bigInteger = new BigInteger(1, md);
            StringBuilder hashText = new StringBuilder(bigInteger.toString(16));
            while (hashText.length() < 32) {
                hashText.insert(0, "0");
            }

            return hashText.toString();
        } catch (Exception e) {
            return null;
        }
    }
}
