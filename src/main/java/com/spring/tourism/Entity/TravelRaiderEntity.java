package com.spring.tourism.Entity;

import javax.persistence.*;
import java.util.Objects;

@Entity
@Table(name = "travel_raider", schema = "public", catalog = "travel")
@IdClass(TravelRaiderEntityPK.class)
public class TravelRaiderEntity {
    private String travelId;
    private String raiderId;

    @Id
    @Column(name = "travel_id")
    public String getTravelId() {
        return travelId;
    }

    public void setTravelId(String travelId) {
        this.travelId = travelId;
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

        TravelRaiderEntity that = (TravelRaiderEntity) o;

        if (!Objects.equals(travelId, that.travelId)) return false;
        if (!Objects.equals(raiderId, that.raiderId)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = travelId != null ? travelId.hashCode() : 0;
        result = 31 * result + (raiderId != null ? raiderId.hashCode() : 0);
        return result;
    }
}
