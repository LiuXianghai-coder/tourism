package com.spring.tourism.Entity;

import javax.persistence.*;
import java.util.Objects;

@Entity
@Table(name = "user_travel_save", schema = "public", catalog = "travel")
@IdClass(UserTravelSaveEntityPK.class)
public class UserTravelSaveEntity {
    private String userId;
    private String travelId;

    @Id
    @Column(name = "user_id")
    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    @Id
    @Column(name = "travel_id")
    public String getTravelId() {
        return travelId;
    }

    public void setTravelId(String travelId) {
        this.travelId = travelId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        UserTravelSaveEntity that = (UserTravelSaveEntity) o;

        if (!Objects.equals(userId, that.userId)) return false;
        return Objects.equals(travelId, that.travelId);
    }

    @Override
    public int hashCode() {
        int result = userId != null ? userId.hashCode() : 0;
        result = 31 * result + (travelId != null ? travelId.hashCode() : 0);
        return result;
    }
}
