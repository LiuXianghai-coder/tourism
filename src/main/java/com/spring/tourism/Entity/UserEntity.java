package com.spring.tourism.Entity;

import javax.persistence.*;
import java.util.Objects;

@Entity
@Table(name = "user", schema = "public", catalog = "travel")
public class UserEntity {
    private String userId;
    private String userPassword;
    private String userName;

    @Id
    @Column(name = "user_id")
    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    @Basic
    @Column(name = "user_password")
    public String getUserPassword() {
        return userPassword;
    }

    public void setUserPassword(String userPassword) {
        this.userPassword = userPassword;
    }

    @Basic
    @Column(name = "user_name")
    public String getUserName() {
        return userName;
    }

    public void setUserName(String userName) {
        this.userName = userName;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        UserEntity that = (UserEntity) o;

        if (!Objects.equals(userId, that.userId)) return false;
        if (!Objects.equals(userPassword, that.userPassword)) return false;
        return Objects.equals(userName, that.userName);
    }

    @Override
    public int hashCode() {
        int result = userId != null ? userId.hashCode() : 0;
        result = 31 * result + (userPassword != null ? userPassword.hashCode() : 0);
        result = 31 * result + (userName != null ? userName.hashCode() : 0);
        return result;
    }
}
