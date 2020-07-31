package com.spring.tourism.Entity;

public class UserFormEntity {
    private String userId;
    private String userPassword;
    private Boolean isRemember;

    public UserFormEntity(){
        userId       = "";
        userPassword = "";
        isRemember   = false;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getUserPassword() {
        return userPassword;
    }

    public void setUserPassword(String userPassword) {
        this.userPassword = userPassword;
    }

    public Boolean getRemember() {
        return isRemember;
    }

    public void setRemember(Boolean remember) {
        isRemember = remember;
    }
}
