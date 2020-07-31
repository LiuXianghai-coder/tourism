package com.spring.tourism.Entity;

import javax.persistence.Column;
import javax.persistence.Id;
import java.io.Serializable;

public class UserTravelSaveEntityPK implements Serializable {
    private String userId;
    private String travelId;

    @Column(name = "user_id")
    @Id
    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    @Column(name = "travel_id")
    @Id
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

        UserTravelSaveEntityPK that = (UserTravelSaveEntityPK) o;

        if (userId != null ? !userId.equals(that.userId) : that.userId != null) return false;
        if (travelId != null ? !travelId.equals(that.travelId) : that.travelId != null) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = userId != null ? userId.hashCode() : 0;
        result = 31 * result + (travelId != null ? travelId.hashCode() : 0);
        return result;
    }
}
