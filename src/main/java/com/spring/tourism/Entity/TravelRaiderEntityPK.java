package com.spring.tourism.Entity;

import javax.persistence.Column;
import javax.persistence.Id;
import java.io.Serializable;
import java.util.Objects;

public class TravelRaiderEntityPK implements Serializable {
    private String travelId;
    private String raiderId;

    @Column(name = "travel_id")
    @Id
    public String getTravelId() {
        return travelId;
    }

    public void setTravelId(String travelId) {
        this.travelId = travelId;
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

        TravelRaiderEntityPK that = (TravelRaiderEntityPK) o;

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
