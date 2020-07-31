package com.spring.tourism.Entity;

public class UserLoginWithCode {
    private String userId;
    private String verifyCode;
    private Boolean remember;

    public UserLoginWithCode(){
        userId = "";
        verifyCode = "";
        remember = false;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getVerifyCode() {
        return verifyCode;
    }

    public void setVerifyCode(String verifyCode) {
        this.verifyCode = verifyCode;
    }

    public Boolean getRemember() {
        return remember;
    }

    public void setRemember(Boolean remember) {
        this.remember = remember;
    }
}
