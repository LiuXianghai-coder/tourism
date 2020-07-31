package com.spring.tourism.Entity;

import javax.persistence.Column;
import javax.persistence.Id;
import java.io.Serializable;
import java.util.Objects;

public class UserTravelBookingEntityPK implements Serializable {
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

        UserTravelBookingEntityPK that = (UserTravelBookingEntityPK) o;

        if (!Objects.equals(userId, that.userId)) return false;
        if (!Objects.equals(travelId, that.travelId)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = userId != null ? userId.hashCode() : 0;
        result = 31 * result + (travelId != null ? travelId.hashCode() : 0);
        return result;
    }
}
