package com.spring.tourism.Entity;

import javax.persistence.*;
import java.sql.Date;

@Entity
@Table(name = "user_star_raider", schema = "public", catalog = "travel")
@IdClass(UserStarRaiderEntityPK.class)
public class UserStarRaiderEntity {
    private String userId;
    private String raiderId;
    private Date starDate;

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

    @Basic
    @Column(name = "star_date")
    public Date getStarDate() {
        return starDate;
    }

    public void setStarDate(Date starDate) {
        this.starDate = starDate;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        UserStarRaiderEntity that = (UserStarRaiderEntity) o;

        if (userId != null ? !userId.equals(that.userId) : that.userId != null) return false;
        if (raiderId != null ? !raiderId.equals(that.raiderId) : that.raiderId != null) return false;
        if (starDate != null ? !starDate.equals(that.starDate) : that.starDate != null) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = userId != null ? userId.hashCode() : 0;
        result = 31 * result + (raiderId != null ? raiderId.hashCode() : 0);
        result = 31 * result + (starDate != null ? starDate.hashCode() : 0);
        return result;
    }
}
