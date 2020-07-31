package com.spring.tourism.Entity;

import javax.persistence.*;
import java.sql.Date;
import java.util.Objects;

@Entity
@Table(name = "user_save_raider", schema = "public", catalog = "travel")
@IdClass(UserSaveRaiderEntityPK.class)
public class UserSaveRaiderEntity {
    private String userId;
    private String raiderId;
    private Date saveDate;

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
    @Column(name = "save_date")
    public Date getSaveDate() {
        return saveDate;
    }

    public void setSaveDate(Date saveDate) {
        this.saveDate = saveDate;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        UserSaveRaiderEntity that = (UserSaveRaiderEntity) o;

        if (!Objects.equals(userId, that.userId)) return false;
        if (!Objects.equals(raiderId, that.raiderId)) return false;
        if (!Objects.equals(saveDate, that.saveDate)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = userId != null ? userId.hashCode() : 0;
        result = 31 * result + (raiderId != null ? raiderId.hashCode() : 0);
        result = 31 * result + (saveDate != null ? saveDate.hashCode() : 0);
        return result;
    }
}
