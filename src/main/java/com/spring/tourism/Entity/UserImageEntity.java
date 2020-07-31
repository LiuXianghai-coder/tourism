package com.spring.tourism.Entity;

import javax.persistence.*;
import java.util.Objects;

@Entity
@Table(name = "user_image", schema = "public", catalog = "travel")
public class UserImageEntity {
    private String userId;
    private String imageAddress;

    @Id
    @Column(name = "user_id")
    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    @Basic
    @Column(name = "image_address")
    public String getImageAddress() {
        return imageAddress;
    }

    public void setImageAddress(String imageAddress) {
        this.imageAddress = imageAddress;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        UserImageEntity that = (UserImageEntity) o;

        if (!Objects.equals(userId, that.userId)) return false;
        return Objects.equals(imageAddress, that.imageAddress);
    }

    @Override
    public int hashCode() {
        int result = userId != null ? userId.hashCode() : 0;
        result = 31 * result + (imageAddress != null ? imageAddress.hashCode() : 0);
        return result;
    }
}
