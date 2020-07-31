package com.spring.tourism.Entity;

import javax.persistence.*;

@Entity
@Table(name = "user_raider", schema = "public", catalog = "travel")
@IdClass(UserRaiderEntityPK.class)
public class UserRaiderEntity {
    private String userId;
    private String raiderId;

    @Id
    @Column(name = "user_id")
    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    @Id
    @Column(name = "raider_id")
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

        UserRaiderEntity that = (UserRaiderEntity) o;

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
