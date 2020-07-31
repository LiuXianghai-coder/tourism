package com.spring.tourism.Entity;

import javax.persistence.Column;
import javax.persistence.Id;
import java.io.Serializable;

public class UserRaiderEntityPK implements Serializable {
    private String userId;
    private String raiderId;

    @Column(name = "user_id")
    @Id
    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    @Column(name = "raider_id")
    @Id
    public String getRaiderId() {
        return raiderId;
    }

    public void setRaiderId(String raiderId) {
        this.raiderId = raiderId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        UserRaiderEntityPK that = (UserRaiderEntityPK) o;

        if (userId != null ? !userId.equals(that.userId) : that.userId != null) return false;
        if (raiderId != null ? !raiderId.equals(that.raiderId) : that.raiderId != null) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = userId != null ? userId.hashCode() : 0;
        result = 31 * result + (raiderId != null ? raiderId.hashCode() : 0);
        return result;
    }
}
