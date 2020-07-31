package com.spring.tourism.Entity;

import javax.persistence.*;
import java.util.Objects;

@Entity
@Table(name = "travel_kind", schema = "public", catalog = "travel")
@IdClass(TravelKindEntityPK.class)
public class TravelKindEntity {
    private String travelId;
    private int kindId;

    @Id
    @Column(name = "travel_id")
    public String getTravelId() {
        return travelId;
    }

    public void setTravelId(String travelId) {
        this.travelId = travelId;
    }

    @Id
    @Column(name = "kind_id")
    public int getKindId() {
        return kindId;
    }

    public void setKindId(int kindId) {
        this.kindId = kindId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        TravelKindEntity that = (TravelKindEntity) o;

        if (kindId != that.kindId) return false;
        if (!Objects.equals(travelId, that.travelId)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = travelId != null ? travelId.hashCode() : 0;
        result = 31 * result + kindId;
        return result;
    }
}
